# Railsapi::Resources

**Note: Railsapi Resources is an experiment at breaking out the Resource class from JSONAPI-Resources. This project 
should be considered a work in progress and may be abandoned at any point. Also this README was quickly extracted from
JR and certainly contains inaccurate information. In addition features may be added or removed at any point. Please do
not base production software on this library.**

## Table of Contents

* [Installation] (#installation)
* [Usage] (#usage)
  * [Resources] (#resources)
    * [Railsapi::Resource] (#jsonapiresource)
    * [Attributes] (#attributes)
    * [Primary Key] (#primary-key)
    * [Model Name] (#model-name)
    * [Model Hints] (#model-hints)
    * [Relationships] (#relationships)
    * [Callbacks] (#callbacks)
    * [Namespaces] (#namespaces)
* [Contributing] (#contributing)
* [License] (#license)

## Installation

Add the gem to your application's `Gemfile`:

    gem 'railsapi-resources'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install railsapi-resources

## Usage

### Resources

Resources define the public interface to your API. A resource defines which attributes are exposed, as well as
relationships to other resources.

Resource definitions should by convention be placed in a directory under app named resources, `app/resources`. The class
name should be the single underscored name of the model that backs the resource with `_resource.rb` appended. For example,
a `Contact` model's resource should have a class named `ContactResource` defined in a file named `contact_resource.rb`.

#### Railsapi::Resource

Resources must be derived from `Railsapi::Resource`, or a class that is itself derived from `Railsapi::Resource`.

For example:

```ruby
class ContactResource < Railsapi::Resource
end
```

##### Abstract Resources

Resources that are not backed by a model (purely used as base classes for other resources) should be declared as
abstract.

Because abstract resources do not expect to be backed by a model, they won't attempt to discover the model class
or any of its relationships.

```ruby
class BaseResource < Railsapi::Resource
  abstract

  has_one :creator
end

class ContactResource < BaseResource
end
```

##### Immutable Resources

Resources that are immutable should be declared as such with the `immutable` method.

###### Immutable Heterogeneous Collections

Immutable resources can be used as the basis for a heterogeneous collection. Resources in heterogeneous collections can
still be mutated through their own type-specific endpoints.

```ruby
class VehicleResource < Railsapi::Resource
  immutable

  has_one :owner
  attributes :make, :model, :serial_number
end

class CarResource < VehicleResource
  attributes :drive_layout
  has_one :driver
end

class BoatResource < VehicleResource
  attributes :length_at_water_line
  has_one :captain
end

# routes
  jsonapi_resources :vehicles
  jsonapi_resources :cars
  jsonapi_resources :boats

```

In the above example vehicles are immutable. A call to `/vehicles` or `/vehicles/1` will return vehicles with types
of either `car` or `boat`. But calls to PUT or POST a `car` must be made to `/cars`. The rails models backing the above
code use Single Table Inheritance.

#### Attributes

Any of a resource's attributes that are accessible must be explicitly declared. Single attributes can be declared using
the `attribute` method, and multiple attributes can be declared with the `attributes` method on the resource class.

For example:

```ruby
class ContactResource < Railsapi::Resource
  attribute :name_first
  attributes :name_last, :email, :twitter
end
```

This resource has 4 defined attributes: `name_first`, `name_last`, `email`, `twitter`, as well as the automatically
defined attributes `id` and `type`. By default these attributes must exist on the model that is handled by the resource.

A resource object wraps a Ruby object, usually an `ActiveModel` record, which is available as the `@model` variable.
This allows a resource's methods to access the underlying model.

For example, a computed attribute for `full_name` could be defined as such:

```ruby
class ContactResource < Railsapi::Resource
  attributes :name_first, :name_last, :email, :twitter
  attribute :full_name

  def full_name
    "#{@model.name_first}, #{@model.name_last}"
  end
end
```

##### Fetchable Attributes

By default all attributes are assumed to be fetchable. The list of fetchable attributes can be filtered by overriding
the `fetchable_fields` method.

Here's an example that prevents guest users from seeing the `email` field:

```ruby
class AuthorResource < Railsapi::Resource
  attributes :name, :email
  model_name 'Person'
  has_many :posts

  def fetchable_fields
    if (context[:current_user].guest)
      super - [:email]
    else
      super
    end
  end
end
```

`fetchable_fields` is only a hint to other components using the resource. It is not enforced by the resource.


##### Creatable and Updatable Attributes

By default all attributes are assumed to be updatable and creatable. To prevent some attributes from being accepted by
the `update` or `create` methods, override the `self.updatable_fields` and `self.creatable_fields` methods on a resource.

This example prevents `full_name` from being set:

```ruby
class ContactResource < Railsapi::Resource
  attributes :name_first, :name_last, :full_name

  def full_name
    "#{@model.name_first}, #{@model.name_last}"
  end

  def self.updatable_fields(context)
    super - [:full_name]
  end

  def self.creatable_fields(context)
    super - [:full_name]
  end
end
```

The `context` is not by default used by the `ResourceController`, but may be used if you override the controller methods.
By using the context you have the option to determine the creatable and updatable fields based on the user.

`updatable_fields` and `creatable_fields` are only hints to other components using the resource. They not enforced by the resource.

##### Sortable Attributes

Railsapi Resources supports [sorting primary resources by multiple sort criteria](http://jsonapi.org/format/#fetching-sorting).

By default all attributes are assumed to be sortable. To prevent some attributes from being sortable, override the
`self.sortable_fields` method on a resource.

Here's an example that prevents sorting by post's `body`:

```ruby
class PostResource < Railsapi::Resource
  attributes :title, :body

  def self.sortable_fields(context)
    super(context) - [:body]
  end
end
```

##### Flattening a Rails relationship

It is possible to flatten Rails relationships into attributes by using getters and setters. This can become handy if a relation needs to be created alongside the creation of the main object which can be the case if there is a bi-directional presence validation. For example:

```ruby
# Given Models
class Person < ActiveRecord::Base
  has_many :spoken_languages
  validates :name, :email, :spoken_languages, presence: true
end

class SpokenLanguage < ActiveRecord::Base
  belongs_to :person, inverse_of: :spoken_languages
  validates :person, :language_code, presence: true
end

# Resource with getters and setter
class PersonResource < Railsapi::Resource
  attributes :name, :email, :spoken_languages

  # Getter
  def spoken_languages
    @model.spoken_languages.pluck(:language_code)
  end

  # Setter (because spoken_languages needed for creation)
  def spoken_languages=(new_spoken_language_codes)
    @model.spoken_languages.destroy_all
    new_spoken_language_codes.each do |new_lang_code|
      @model.spoken_languages.build(language_code: new_lang_code)
    end
  end
end
```

#### Primary Key

Resources are always represented using a key of `id`. The resource will interrogate the model to find the primary key.
If the underlying model does not use `id` as the primary key _and_ does not support the `primary_key` method you
must use the `primary_key` method to tell the resource which field on the model to use as the primary key. **Note:**
this _must_ be the actual primary key of the model.

By default only integer values are allowed for primary key. To change this behavior you can set the `resource_key_type`
configuration option:

```ruby
JSONAPI.configure do |config|
  # Allowed values are :integer(default), :uuid, :string, or a proc
  config.resource_key_type = :uuid
end
```

##### Override key type on a resource

You can override the default resource key type on a per-resource basis by calling `key_type` in the resource class,
with the same allowed values as the `resource_key_type` configuration option.

```ruby
class ContactResource < Railsapi::Resource
  attribute :id
  attributes :name_first, :name_last, :email, :twitter
  key_type :uuid
end
```

##### Custom resource key validators

If you need more control over the key, you can override the #verify_key method on your resource, or set a lambda that
accepts key and context arguments in `config/initializers/jsonapi_resources.rb`:

```ruby
JSONAPI.configure do |config|
  config.resource_key_type = -> (key, context) { key && String(key) }
end
```

#### Model Name

The name of the underlying model is inferred from the Resource name. It can be overridden by use of the `model_name`
method. For example:

```ruby
class AuthorResource < Railsapi::Resource
  attribute :name
  model_name 'Person'
  has_many :posts
end
```

#### Model Hints

Resource instances are created from model records. The determination of the correct resource type is performed using a
simple rule based on the model's name. The name is used to find a resource in the same module (as the originating
resource) that matches the name. This usually works quite well, however it can fail when model names do not match
resource names. It can also fail when using namespaced models. In this case a `model_hint` can be created to map model
names to resources. For example:

```ruby
class AuthorResource < Railsapi::Resource
  attribute :name
  model_name 'Person'
  model_hint model: Commenter, resource: :special_person

  has_many :posts
  has_many :commenters
end
```

Note that when `model_name` is set a corresponding `model_hint` is also added. This can be skipped by using the
`add_model_hint` option set to false. For example:

```ruby
class AuthorResource < Railsapi::Resource
  model_name 'Legacy::Person', add_model_hint: false
end
```

Model hints inherit from parent resources, but are not global in scope. The `model_hint` method accepts `model` and
`resource` named parameters. `model` takes an ActiveRecord class or class name (defaults to the model name), and
`resource` takes a resource type or a resource class (defaults to the current resource's type).

#### Relationships

Related resources need to be specified in the resource. These may be declared with the `relationship` or the `has_one`
and the `has_many` methods.

Here's a simple example using the `relationship` method where a post has a single author and an author can have many
posts:

```ruby
class PostResource < Railsapi::Resource
  attributes :title, :body

  relationship :author, to: :one
end
```

And the corresponding author:

```ruby
class AuthorResource < Railsapi::Resource
  attribute :name

  relationship :posts, to: :many
end
```

And here's the equivalent resources using the `has_one` and `has_many` methods:

```ruby
class PostResource < Railsapi::Resource
  attributes :title, :body

  has_one :author
end
```

And the corresponding author:

```ruby
class AuthorResource < Railsapi::Resource
  attribute :name

  has_many :posts
end
```

##### Options

The relationship methods (`relationship`, `has_one`, and `has_many`) support the following options:

 * `class_name` - a string specifying the underlying class for the related resource. Defaults to the `class_name` property on the underlying model.
 * `foreign_key` - the method on the resource used to fetch the related resource. Defaults to `<resource_name>_id` for has_one and `<resource_name>_ids` for has_many relationships.
 * `acts_as_set` - allows the entire set of related records to be replaced in one operation. Defaults to false if not set.
 * `polymorphic` - set to true to identify relationships that are polymorphic.
 * `relation_name` - the name of the relation to use on the model. A lambda may be provided which allows conditional selection of the relation based on the context.
 * `always_include_linkage_data` - if set to true, the relationship includes linkage data. Defaults to false if not set.

`to_one` relationships support the additional option:
 * `foreign_key_on` - defaults to `:self`. To indicate that the foreign key is on the related resource specify `:related`.

Examples:

```ruby
class CommentResource < Railsapi::Resource
  attributes :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags, acts_as_set: true
end

class ExpenseEntryResource < Railsapi::Resource
  attributes :cost, :transaction_date

  has_one :currency, class_name: 'Currency', foreign_key: 'currency_code'
  has_one :employee
end

class TagResource < Railsapi::Resource
  attributes :name
  has_one :taggable, polymorphic: true
end
```

```ruby
class BookResource < Railsapi::Resource

  # Only book_admins may see unapproved comments for a book. Using
  # a lambda to select the correct relation on the model
  has_many :book_comments, relation_name: -> (options = {}) {
    context = options[:context]
    current_user = context ? context[:current_user] : nil

    unless current_user && current_user.book_admin
      :approved_book_comments
    else
      :book_comments
    end
  }
  ...
end
```

The polymorphic relationship will require the resource and controller to exist, although routing to them will cause an
error.

```ruby
class TaggableResource < Railsapi::Resource; end
class TaggablesController < Railsapi::ResourceController; end
```

#### Callbacks

`ActiveSupport::Callbacks` is used to provide callback functionality, so the behavior is very similar to what you may be
used to from `ActiveRecord`.

For example, you might use a callback to perform authorization on your resource before an action.

```ruby
class BaseResource < Railsapi::Resource
  before_create :authorize_create

  def authorize_create
    # ...
  end
end
```

The types of supported callbacks are:
- `before`
- `after`
- `around`

##### `Railsapi::ResourceCallbacks`

Callbacks can be defined for the following `Railsapi::Resource` events:

- `:create`
- `:update`
- `:remove`
- `:save`
- `:create_to_many_link`
- `:replace_to_many_links`
- `:create_to_one_link`
- `:replace_to_one_link`
- `:remove_to_many_link`
- `:remove_to_one_link`
- `:replace_fields`

#### Namespaces

Railsapi::Resources supports namespacing of resources. With namespacing you can version your API.

## Contributing

1. Fork it ( http://github.com/cerebris/railsapi-resources/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Copyright 2016 Cerebris Corporation. MIT License (see LICENSE for details).
