require File.expand_path('../../test_helper', __FILE__)

class Railsapi::ResourceTest < Minitest::Test
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal("Post", PostResource._model_name)
  end

  def test_model_name_of_subclassed_non_abstract_resource
    assert_equal("Firm", FirmResource._model_name)
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_module_path
    assert_equal(MyModule::MyNamespacedResource.module_path, 'my_module/')
  end

  def test_resource_for_root_resource
    assert_raises NameError do
      Railsapi::Resource.resource_for('related')
    end
  end

  def test_resource_for_with_namespaced_paths
    assert_equal(Railsapi::Resource.resource_for('my_module/related'), MyModule::RelatedResource)
    assert_equal(PostResource.resource_for('my_module/related'), MyModule::RelatedResource)
    assert_equal(MyModule::MyNamespacedResource.resource_for('my_module/related'), MyModule::RelatedResource)
  end

  def test_resource_for_resource_does_not_exist_at_root
    assert_raises NameError do
      ArticleResource.resource_for('related')
    end
    assert_raises NameError do
      Railsapi::Resource.resource_for('related')
    end
  end

  def test_resource_for_namespaced_resource
    assert_equal(MyModule::MyNamespacedResource.resource_for('related'), MyModule::RelatedResource)
  end

  def test_relationship_parent_point_to_correct_resource
    assert_equal MyModule::MyNamespacedResource, MyModule::MyNamespacedResource._relationships[:related].parent_resource
  end

  def test_relationship_parent_option_point_to_correct_resource
    assert_equal MyModule::MyNamespacedResource, MyModule::MyNamespacedResource._relationships[:related].options[:parent_resource]
  end

  def test_derived_resources_relationships_parent_point_to_correct_resource
    assert_equal MyAPI::MyNamespacedResource, MyAPI::MyNamespacedResource._relationships[:related].parent_resource
  end

  def test_derived_resources_relationships_parent_options_point_to_correct_resource
    assert_equal MyAPI::MyNamespacedResource, MyAPI::MyNamespacedResource._relationships[:related].options[:parent_resource]
  end

  def test_base_resource_abstract
    assert BaseResource._abstract
  end

  def test_derived_not_abstract
    assert PersonResource < BaseResource
    refute PersonResource._abstract
  end

  def test_nil_model_class
    # ToDo:Figure out why this test does not work on Rails 4.0
    # :nocov:
    if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR >= 1
      assert_output nil, "[MODEL NOT FOUND] Model could not be found for NoMatchResource. If this a base Resource declare it as abstract.\n" do
        assert_nil NoMatchResource._model_class
      end
    end
    # :nocov:
  end

  def test_nil_abstract_model_class
    assert_output nil, '' do
      assert_nil NoMatchAbstractResource._model_class
    end
  end

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_relationships
    relationships = CatResource._relationships
    assert_kind_of(Hash, relationships)
    assert_equal(relationships.size, 2)
  end

  def test_updatable_fields_does_not_include_id
    assert(!CatResource.updatable_fields.include?(:id))
  end

  def test_key_type_integer
    CatResource.instance_eval do
      key_type :integer
    end

    assert CatResource.verify_key('45')
    assert CatResource.verify_key(45)

    assert_raises Railsapi::Exceptions::InvalidFieldValue do
      CatResource.verify_key('45,345')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_string
    CatResource.instance_eval do
      key_type :string
    end

    assert CatResource.verify_key('45')
    assert CatResource.verify_key(45)

    assert_raises Railsapi::Exceptions::InvalidFieldValue do
      CatResource.verify_key('45,345')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_uuid
    CatResource.instance_eval do
      key_type :uuid
    end

    assert CatResource.verify_key('f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5')

    assert_raises Railsapi::Exceptions::InvalidFieldValue do
      CatResource.verify_key('f1a-e77a-4d0a-acbb-ee0b98b3f6b5')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_proc
    CatResource.instance_eval do
      key_type -> (key, context) {
        return key if key.nil?
        if key.to_s.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
          key
        else
          raise Railsapi::Exceptions::InvalidFieldValue.new(:id, key)
        end
      }
    end

    assert CatResource.verify_key('f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5')

    assert_raises Railsapi::Exceptions::InvalidFieldValue do
      CatResource.verify_key('f1a-e77a-4d0a-acbb-ee0b98b3f6b5')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_links_resource_warning
    _out, err = capture_io do
      eval "class LinksResource < Railsapi::Resource; end"
    end
    assert_match /LinksResource` is a reserved resource name/, err
  end

  def test_reserved_key_warnings
    _out, err = capture_io do
      eval <<-CODE
        class BadlyNamedAttributesResource < Railsapi::Resource
          attributes :type
        end
      CODE
    end
    assert_match /`type` is a reserved key in ./, err
  end

  def test_reserved_relationship_warnings
    %w(id type).each do |key|
      _out, err = capture_io do
        eval <<-CODE
          class BadlyNamedAttributesResource < Railsapi::Resource
            has_one :#{key}
          end
        CODE
      end
      assert_match /`#{key}` is a reserved relationship name in ./, err
    end
    %w(types ids).each do |key|
      _out, err = capture_io do
        eval <<-CODE
          class BadlyNamedAttributesResource < Railsapi::Resource
            has_many :#{key}
          end
        CODE
      end
      assert_match /`#{key}` is a reserved relationship name in ./, err
    end
  end

  def test_abstract_warning
    _out, err = capture_io do
      eval <<-CODE
        class NoModelResource < Railsapi::Resource
        end
        NoModelResource._model_class
      CODE
    end
    assert_match "[MODEL NOT FOUND] Model could not be found for Railsapi::ResourceTest::NoModelResource. If this a base Resource declare it as abstract.\n", err
  end

  def test_no_warning_when_abstract
    _out, err = capture_io do
      eval <<-CODE
        class NoModelAbstractResource < Railsapi::Resource
          abstract
        end
        NoModelAbstractResource._model_class
      CODE
    end
    assert_match "", err
  end

  def test_correct_error_surfaced_if_validation_errors_in_after_save_callback
    post = PostWithBadAfterSave.find(1)
    post_resource = ArticleWithBadAfterSaveResource.new(post, nil)
    err = assert_raises Railsapi::Exceptions::ValidationErrors do
      post_resource.replace_fields({:attributes => {:title => 'Some title'}})
    end
    assert_equal(err.error_messages[:base], ['Boom! Error added in after_save callback.'])
  end
end