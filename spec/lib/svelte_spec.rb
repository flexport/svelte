# frozen_string_literal: true

require 'spec_helper'

describe Svelte do
  describe '#create' do
    let(:json) { File.read('spec/fixtures/petstore.json') }
    let(:module_name) { 'PetStore' }
    let(:options) do
      {
        protocol: 'http'
      }
    end

    shared_examples 'builds all the things' do
      let(:operations) do
        %w[
          addPet
          updatePet
          getPetById
          updatePetWithForm
          deletePet
          findPetsByStatus
          findPetsByTags
          uploadFile
          getInventory
          placeOrder
          getOrderById
          deleteOrder
          getInventory
          createUsersWithArrayInput
          createUsersWithListInput
          loginUser
          logoutUser
          createUser
          getUserByName
          updateUser
          deleteUser
        ]
      end

      it 'creates the correct module inside Svelte::Service namespace' do
        expect(described_class::Service.const_defined?(module_name)).to eq(true)
      end

      it 'creates the operations for each module' do
        operations.each do |operation|
          method_name = Svelte::StringManipulator.method_name_for(operation)
          expect(described_class::Service.const_get(module_name))
            .to(respond_to(method_name),
                "Expected module to respond to :#{operation}, but it didn't")
        end
      end
    end

    context 'with an inline json' do
      before do
        described_class.create(json: json, module_name: module_name, options: options)
      end

      include_examples 'builds all the things'
    end

    context 'with an online json' do
      let(:url) { 'http://www.example.com/petstore.json' }

      context 'with default options' do
        before do
          stub_request(:any, url)
            .to_return(body: json, status: 200)

          described_class.create(url: url, module_name: module_name)
        end

        include_examples 'builds all the things'

        it 'raises a Svelte::HTTPException on http errors' do
          stub_request(:any, url).to_timeout

          expect { described_class.create(url: url, module_name: module_name, options: options) }
            .to raise_error(Svelte::HTTPError, "Could not get API json from #{url}")
        end
      end

      context 'with a bearer token' do
        it 'sets the correct headers' do
          stub_request(:any, url)
            .to_return(body: json, status: 200)

          described_class.create(url: url, module_name: module_name, options: {
                                   auth: { token: 'Bearer 12345' }
                                 })

          assert_requested(:any, url, headers: { 'Authorization' => 'Bearer 12345' })
        end
      end

      context 'with basic authentication' do
        it 'sets the correct headers' do
          stub_request(:any, url)
            .to_return(body: json, status: 200)

          described_class.create(url: url, module_name: module_name, options: {
                                   auth: { basic: { username: 'user', password: 'pass' } }
                                 })

          assert_requested(:any, url, headers: { 'Authorization' => 'Basic dXNlcjpwYXNz' })
        end
      end

      context 'with arbitrary headers' do
        it 'sets the correct headers' do
          stub_request(:any, url)
            .to_return(body: json, status: 200)

          described_class.create(url: url, module_name: module_name, options: {
                                   headers: { test: 'value' }
                                 })

          assert_requested(:any, url, headers: { 'test' => 'value' })
        end
      end
    end

    context 'with invalid host' do
      let(:json) { File.read('spec/fixtures/petstore_with_invalid_host.json') }

      it 'raises a JSONError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::JSONError,
                          '`host` field in JSON is invalid')
      end
    end

    context 'with invalid basePath' do
      let(:json) { File.read('spec/fixtures/petstore_with_invalid_base_path.json') }

      it 'raises a JSONError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::JSONError,
                          '`basePath` field in JSON is invalid')
      end
    end

    context 'with invalid paths' do
      let(:json) { File.read('spec/fixtures/petstore_with_invalid_paths.json') }

      it 'raises a JSONError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::JSONError,
                          'Expected JSON to contain an object of valid paths')
      end
    end

    context 'with invalid operations' do
      let(:json) { File.read('spec/fixtures/petstore_with_invalid_operations.json') }

      it 'raises a JSONError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::JSONError,
                          'Expected the path to contain a list of operations')
      end
    end

    context 'with operations missing mandatory values' do
      let(:json) { File.read('spec/fixtures/petstore_without_mandatory_operation_fields.json') }

      it 'raises a JSONError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::JSONError,
                          'Operation is missing mandatory `operationId` field')
      end
    end

    context 'with a version 1.2 JSON spec' do
      let(:json) { File.read('spec/fixtures/petstore_1.2.json') }

      it 'raises a VersionError exception' do
        expect { described_class.create(json: json, module_name: module_name) }
          .to raise_error(Svelte::VersionError,
                          'Invalid Swagger version spec supplied. Svelte supports Swagger v2 only')
      end
    end
  end
end
