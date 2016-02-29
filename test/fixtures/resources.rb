require 'railsapi-resources'

### RESOURCES
class BaseResource < RailsAPI::Resource
  abstract
end

class PersonResource < BaseResource
  attributes :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments
  has_many :posts
  has_many :vehicles, polymorphic: true

  has_one :preferences
  has_one :hair_cut
end

class SpecialBaseResource < BaseResource
  abstract

  model_hint model: Person, resource: :special_person
end

class SpecialPersonResource < SpecialBaseResource
  model_name 'Person'
end

class CommentResource < RailsAPI::Resource
  attributes :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags
end

class CompanyResource < RailsAPI::Resource
  attributes :name, :address
end

class FirmResource < CompanyResource
end

class TagResource < RailsAPI::Resource
  attributes :name

  has_many :posts
end


class PostResource < RailsAPI::Resource
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_one :section
  has_many :tags, acts_as_set: true
  has_many :comments, acts_as_set: false


  # Not needed - just for testing
  primary_key :id

  before_save do
    msg = "Before save"
  end

  after_save do
    msg = "After save"
  end

  before_update do
    msg = "Before update"
  end

  after_update do
    msg = "After update"
  end

  before_replace_fields do
    msg = "Before replace_fields"
  end

  after_replace_fields do
    msg = "After replace_fields"
  end

  around_update :around_update_check

  def around_update_check
    # do nothing
    yield
    # do nothing
  end

  def subject
    @model.title
  end

  def title=(title)
    @model.title = title
    if title == 'BOOM'
      raise 'The Server just tested going boom. If this was a real emergency you would be really dead right now.'
    end
  end

  def self.updatable_fields(context)
    super(context) - [:author, :subject]
  end

  def self.creatable_fields(context)
    super(context) - [:subject]
  end

  def self.sortable_fields(context)
    super(context) - [:id]
  end

  def self.verify_key(key, context = nil)
    super(key)
    raise RailsAPI::Exceptions::RecordNotFound.new(key) unless find_by_key(key, context: context)
    return key
  end
end

class PreferencesResource < RailsAPI::Resource
  attribute :advanced_mode

  has_one :author, :foreign_key_on => :related

  def self.find_by_key(key, options = {})
    new(Preferences.first, nil)
  end
end

class AuthorResource < RailsAPI::Resource
  model_name 'Person'
  attributes :name
end

class BookResource < RailsAPI::Resource
  has_many :authors, class_name: 'Author'
end

class AuthorDetailResource < RailsAPI::Resource
  attributes :author_stuff
end

module Api
  module V2
    # class PreferencesResource < PreferencesResource; end
    # class PersonResource < PersonResource; end
    # class PostResource < PostResource; end

    class BookResource < RailsAPI::Resource
      attribute :title
      attributes :isbn, :banned

      has_many :book_comments, relation_name: -> (options = {}) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        unless current_user && current_user.book_admin
          :approved_book_comments
        else
          :book_comments
        end
      }

      has_many :aliased_comments, class_name: 'BookComments', relation_name: :approved_book_comments

      class << self
        def books
          Book.arel_table
        end

        def not_banned_books
          books[:banned].eq(false)
        end
      end
    end

    class BookCommentResource < RailsAPI::Resource
      attributes :body, :approved

      has_one :book
      has_one :author, class_name: 'Person'

      class << self
        def book_comments
          BookComment.arel_table
        end

        def approved_comments(approved = true)
          book_comments[:approved].eq(approved)
        end
      end
    end
  end
end

class ArticleResource < RailsAPI::Resource
  model_name 'Post'
end

class PostWithBadAfterSave < ActiveRecord::Base
  self.table_name = 'posts'
  after_save :do_some_after_save_stuff

  def do_some_after_save_stuff
    errors[:base] << 'Boom! Error added in after_save callback.'
    raise ActiveRecord::RecordInvalid.new(self)
  end
end

class ArticleWithBadAfterSaveResource < RailsAPI::Resource
  model_name 'PostWithBadAfterSave'
  attribute :title
end

class NoMatchResource < RailsAPI::Resource
end

class NoMatchAbstractResource < RailsAPI::Resource
  abstract
end

class CatResource < RailsAPI::Resource
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

module MyModule
  class MyNamespacedResource < RailsAPI::Resource
    model_name "Person"
    has_many :related
  end

  class RelatedResource < RailsAPI::Resource
    model_name "Comment"
  end
end

module MyAPI
  class MyNamespacedResource < MyModule::MyNamespacedResource
  end

  class RelatedResource < MyModule::RelatedResource
  end
end

module Api
  module V8
    class NumeroTelefoneResource < RailsAPI::Resource
      attribute :numero_telefone
    end
  end
end