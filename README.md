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
    * [Relationships] (#relationships)
    * [Filters] (#filters)
    * [Pagination] (#pagination)
    * [Included relationships (side-loading resources)] (#included-relationships-side-loading-resources)
    * [Resource meta] (#resource-meta)
    * [Custom Links] (#resource-meta)
    * [Callbacks] (#callbacks)
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

##### Attribute Formatting

Attributes can have a `Format`. By default all attributes use the default formatter. If an attribute has the `format`
option set the system will attempt to find a formatter based on this name. In the following example the `last_login_time`
will be returned formatted to a certain time zone:

```ruby
class PersonResource < Railsapi::Resource
  attributes :name, :email
  attribute :last_login_time, format: :date_with_timezone
end
```

The system will lookup a value formatter named `DateWithTimezoneValueFormatter` and will use this when serializing and
updating the attribute. See the [Value Formatters](#value-formatters) section for more details.

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

#### Filters

Filters for locating objects of the resource type are specified in the resource definition. Single filters can be
declared using the `filter` method, and multiple filters can be declared with the `filters` method on the resource
class.

For example:

```ruby
class ContactResource < Railsapi::Resource
  attributes :name_first, :name_last, :email, :twitter

  filter :id
  filters :name_first, :name_last
end
```

Then a request could pass in a filter for example `http://example.com/contacts?filter[name_last]=Smith` and the system
will find all people where the last name exactly matches Smith.

##### Default Filters

A default filter may be defined for a resource using the `default` option on the `filter` method. This default is used
unless the request overrides this value.

For example:

```ruby
 class CommentResource < Railsapi::Resource
  attributes :body, :status
  has_one :post
  has_one :author

  filter :status, default: 'published,pending'
end
```

The default value is used as if it came from the request.

##### Applying Filters

You may customize how a filter behaves by supplying a callable to the `:apply` option. This callable will be used to
apply that filter. The callable is passed the `records`, which is an `ActiveRecord::Relation`, the `value`, and an
`_options` hash. It is expected to return an `ActiveRecord::Relation`.

This example shows how you can implement different approaches for different filters.

```ruby
filter :visibility, apply: ->(records, value, _options) {
  records.where('users.publicly_visible = ?', value == :public)
}
```

If you omit the `apply` callable the filter will be applied as `records.where(filter => value)`.

Note: It is also possible to override the `self.apply_filter` method, though this approach is now deprecated:

```ruby
def self.apply_filter(records, filter, value, options)
  case filter
    when :last_name, :first_name, :name
      if value.is_a?(Array)
        value.each do |val|
          records = records.where(_model_class.arel_table[filter].matches(val))
        end
        return records
      else
        records.where(_model_class.arel_table[filter].matches(value))
      end
    else
      return super(records, filter, value)
  end
end
```

##### Verifying Filters

Because filters typically come straight from the request, it's prudent to verify their values. To do so, provide a
callable to the `verify` option. This callable will be passed the `value` and the `context`. Verify should return the
verified value, which may be modified.

```ruby
  filter :ids,
         verify: ->(values, context) {
           verify_keys(values, context)
           return values
         },
         apply: -> (records, value, _options) {
           records.where('id IN (?)', value)
         }
```

##### Finders

Basic finding by filters is supported by resources. This is implemented in the `find` and `find_by_key` finder methods.
Currently this is implemented for `ActiveRecord` based resources. The finder methods rely on the `records` method to get
an `ActiveRecord::Relation` relation. It is therefore possible to override `records` to affect the three find related
methods.

###### Customizing base records for finder methods

If you need to change the base records on which `find` and `find_by_key` operate, you can override the `records` method
on the resource class.

For example to allow a user to only retrieve his own posts you can do the following:

```ruby
class PostResource < Railsapi::Resource
  attributes :title, :body

  def self.records(options = {})
    context = options[:context]
    context[:current_user].posts
  end
end
```

When you create a relationship, a method is created to fetch record(s) for that relationship, using the relation name
for the relationship.

```ruby
class PostResource < Railsapi::Resource
  has_one :author
  has_many :comments

  # def record_for_author
  #   relation_name = relationship.relation_name(context: @context)
  #   records_for(relation_name)
  # end

  # def records_for_comments
  #   relation_name = relationship.relation_name(context: @context)
  #   records_for(relation_name)
  # end
end

```

For example, you may want to raise an error if the user is not authorized to view the related records. See the next
section for additional details on raising errors.

```ruby
class BaseResource < Railsapi::Resource
  def records_for(relation_name)
    context = options[:context]
    records = _model.public_send(relation_name)

    unless context[:current_user].can_view?(records)
      raise NotAuthorizedError
    end

    records
  end
end
```

###### Raising Errors

Inside the finder methods (like `records_for`) or inside of resource callbacks
(like `before_save`) you can `raise` an error to halt processing. Railsapi::Resources
has some built in errors that will return appropriate error codes. By
default any other error that you raise will return a `500` status code
for a general internal server error.

To return useful error codes that represent application errors you
should set the `exception_class_whitelist` config varible, and then you
should use the Rails `rescue_from` macro to render a status code.

For example, this config setting allows the `NotAuthorizedError` to bubble up out of
Railsapi::Resources and into your application.

```ruby
# config/initializer/railsapi-resources.rb
JSONAPI.configure do |config|
  config.exception_class_whitelist = [NotAuthorizedError]
end
```

Handling the error and rendering the appropriate code is now the resonsiblity of the
application and could be handled like this:

```ruby
class ApiController < ApplicationController
  rescue_from NotAuthorizedError, with: :reject_forbidden_request
  def reject_forbidden_request
    render json: {error: 'Forbidden'}, :status => 403
  end
end
```


###### Applying Filters

The `apply_filter` method is called to apply each filter to the `Arel` relation. You may override this method to gain
control over how the filters are applied to the `Arel` relation.

This example shows how you can implement different approaches for different filters.

```ruby
def self.apply_filter(records, filter, value, options)
  case filter
    when :visibility
      records.where('users.publicly_visible = ?', value == :public)
    when :last_name, :first_name, :name
      if value.is_a?(Array)
        value.each do |val|
          records = records.where(_model_class.arel_table[filter].matches(val))
        end
        return records
      else
        records.where(_model_class.arel_table[filter].matches(value))
      end
    else
      return super(records, filter, value)
  end
end
```


###### Applying Sorting

You can override the `apply_sort` method to gain control over how the sorting is done. This may be useful in case you'd
like to base the sorting on variables in your context.

Example:

```ruby
def self.apply_sort(records, order_options, context = {})
  if order_options.has?(:trending)
    records = records.order_by_trending_scope
    order_options - [:trending]
  end

  super(records, order_options, context)
end
```


###### Override finder methods

Finally if you have more complex requirements for finding you can override the `find` and `find_by_key` methods on the
resource class.

Here's an example that defers the `find` operation to a `current_user` set on the `context` option:

```ruby
class AuthorResource < Railsapi::Resource
  attribute :name
  model_name 'Person'
  has_many :posts

  filter :name

  def self.find(filters, options = {})
    context = options[:context]
    authors = context[:current_user].find_authors(filters)

    return authors.map do |author|
      self.new(author, context)
    end
  end
end
```

#### Pagination

Pagination is performed using a `paginator`, which is a class responsible for parsing the `page` request parameters and
applying the pagination logic to the results.

##### Paginators

`Railsapi::Resource` supports several pagination methods by default, and allows you to implement a custom system if the
defaults do not meet your needs.

###### Paged Paginator

The `paged` `paginator` returns results based on pages of a fixed size. Valid `page` parameters are `number` and `size`.
If `number` is omitted the first page is returned. If `size` is omitted the `default_page_size` from the configuration
settings is used.

```
GET /articles?page%5Bnumber%5D=10&page%5Bsize%5D=10 HTTP/1.1
Accept: application/vnd.api+json
```

###### Offset Paginator

The `offset` `paginator` returns results based on an offset from the beginning of the resultset. Valid `page` parameters
are `offset` and `limit`. If `offset` is omitted a value of 0 will be used. If `limit` is omitted the `default_page_size`
from the configuration settings is used.

```
GET /articles?page%5Blimit%5D=10&page%5Boffset%5D=10 HTTP/1.1
Accept: application/vnd.api+json
```

###### Custom Paginators

Custom `paginators` can be used. These should derive from `Paginator`. The `apply` method takes a `relation` and
`order_options` and is expected to return a `relation`. The `initialize` method receives the parameters from the `page`
request parameters. It is up to the paginator author to parse and validate these parameters.

For example, here is a very simple single record at a time paginator:

```ruby
class SingleRecordPaginator < Railsapi::Paginator
  def initialize(params)
    # param parsing and validation here
    @page = params.to_i
  end

  def apply(relation, order_options)
    relation.offset(@page).limit(1)
  end
end
```

##### Paginator Configuration

The default paginator, which will be used for all resources, is set using `JSONAPI.configure`. For example, in your
`config/initializers/jsonapi_resources.rb`:

```ruby
JSONAPI.configure do |config|
  # built in paginators are :none, :offset, :paged
  config.default_paginator = :offset

  config.default_page_size = 10
  config.maximum_page_size = 20
end
```

If no `default_paginator` is configured, pagination will be disabled by default.

Paginators can also be set at the resource-level, which will override the default setting. This is done using the
`paginator` method:

```ruby
class BookResource < Railsapi::Resource
  attribute :title
  attribute :isbn

  paginator :offset
end
```

To disable pagination in a resource, specify `:none` for `paginator`.

#### Included relationships (side-loading resources)

Railsapi Resources supports [request include params](http://jsonapi.org/format/#fetching-includes) out of the box, for side loading related resources.

Here's an example from the spec:

```
GET /articles/1?include=comments HTTP/1.1
Accept: application/vnd.api+json
```

Will get you the following payload by default:

```
{
  "data": {
    "type": "articles",
    "id": "1",
    "attributes": {
      "title": "JSON API paints my bikeshed!"
    },
    "links": {
      "self": "http://example.com/articles/1"
    },
    "relationships": {
      "comments": {
        "links": {
          "self": "http://example.com/articles/1/relationships/comments",
          "related": "http://example.com/articles/1/comments"
        },
        "data": [
          { "type": "comments", "id": "5" },
          { "type": "comments", "id": "12" }
        ]
      }
    }
  },
  "included": [{
    "type": "comments",
    "id": "5",
    "attributes": {
      "body": "First!"
    },
    "links": {
      "self": "http://example.com/comments/5"
    }
  }, {
    "type": "comments",
    "id": "12",
    "attributes": {
      "body": "I like XML better"
    },
    "links": {
      "self": "http://example.com/comments/12"
    }
  }]
}
```

#### Resource Meta

Meta information can be included for each resource using the meta method in the resource declaration. For example:

```ruby
class BookResource < Railsapi::Resource
  attribute :title
  attribute :isbn

  def meta(options)
    {
      copyright: 'API Copyright 2015 - XYZ Corp.',
      computed_copyright: options[:serialization_options][:copyright]
      last_updated_at: _model.updated_at
    }
   end
end

```

The `meta` method will be called for each resource instance. Override the `meta` method on a resource class to control
the meta information for the resource. If a non empty hash is returned from `meta` this will be serialized. The `meta`
method is called with an `options` has. The `options` hash will contain the following:

 * `:serializer` -> the serializer instance
 * `:serialization_options` -> the contents of the `serialization_options` method on the controller.

#### Custom Links

Custom links can be included for each resource by overriding the `custom_links` method. If a non empty hash is returned from `custom_links`, it will be merged with the default links hash containing the resource's `self` link. The `custom_links` method is called with the same `options` hash used by for [resource meta information](#resource-meta). The `options` hash contains the following:

 * `:serializer` -> the serializer instance
 * `:serialization_options` -> the contents of the `serialization_options` method on the controller.

For example:

```ruby
class CityCouncilMeeting < Railsapi::Resource
  attribute :title, :location, :approved

  def custom_links(options)
    { minutes: options[:serialzer].link_builder.self_link(self) + "/minutes" }
  end
end
```

This will create a custom link with the key `minutes`, which will be merged with the default `self` link, like so:

```json
{
  "data": [
    {
      "id": "1",
      "type": "cityCouncilMeetings",
      "links": {
        "self": "http://city.gov/api/city-council-meetings/1",
        "minutes": "http://city.gov/api/city-council-meetings/1/minutes"
      },
      "attributes": {...}
    },
    //...
  ]
}
```

Of course, the `custom_links` method can include logic to include links only when relevant:

````ruby
class CityCouncilMeeting < Railsapi::Resource
  attribute :title, :location, :approved

  delegate :approved?, to: :model

  def custom_links(options)
    extra_links = {}
    if approved?
      extra_links[:minutes] = options[:serialzer].link_builder.self_link(self) + "/minutes"
    end
    extra_links
  end
end
```

It's also possibly to suppress the default `self` link by returning a hash with `{self: nil}`:

````ruby
class Selfless < Railsapi::Resource
  def custom_links(options)
    {self: nil}
  end
end
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

##### `Railsapi::Resource` Callbacks

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

##### `Railsapi::OperationsProcessor` Callbacks

Callbacks can also be defined for `Railsapi::OperationsProcessor` events:
- `:operations`: The set of operations.
- `:operation`: Any individual operation.
- `:find_operation`: A `find_operation`.
- `:show_operation`: A `show_operation`.
- `:show_relationship_operation`: A `show_relationship_operation`.
- `:show_related_resource_operation`: A `show_related_resource_operation`.
- `:show_related_resources_operation`: A `show_related_resources_operation`.
- `:create_resource_operation`: A `create_resource_operation`.
- `:remove_resource_operation`: A `remove_resource_operation`.
- `:replace_fields_operation`: A `replace_fields_operation`.
- `:replace_to_one_relationship_operation`: A `replace_to_one_relationship_operation`.
- `:create_to_many_relationship_operation`: A `create_to_many_relationship_operation`.
- `:replace_to_many_relationship_operation`: A `replace_to_many_relationship_operation`.
- `:remove_to_many_relationship_operation`: A `remove_to_many_relationship_operation`.
- `:remove_to_one_relationship_operation`: A `remove_to_one_relationship_operation`.

The operation callbacks have access to two meta data hashes, `@operations_meta` and `@operation_meta`, two links hashes,
`@operations_links` and `@operation_links`, the full list of `@operations`, each individual `@operation` and the
`@result` variables.

##### Custom `OperationsProcessor` Example to Return total_count in Meta

Note: this can also be accomplished with the `top_level_meta_include_record_count` option, and in most cases that will
be the better option.

To return the total record count of a find operation in the meta data of a find operation you can create a custom
OperationsProcessor. For example:

```ruby
# lib/jsonapi/counting_active_record_operations_processor.rb
class CountingActiveRecordOperationsProcessor < ActiveRecordOperationsProcessor
  after_find_operation do
    @operation_meta[:total_records] = @operation.record_count
  end
end
```

Set the configuration option `operations_processor` to use the new `CountingActiveRecordOperationsProcessor` by
specifying the snake cased name of the class (without the `OperationsProcessor`).

```ruby
require 'jsonapi/counting_active_record_operations_processor'

JSONAPI.configure do |config|
  config.operations_processor = :counting_active_record
end
```

To use a specific `OperationsProcessor` in a `ResourceController`, override the `create_operations_processor` method:

```ruby
def create_operations_processor
  CountingActiveRecordOperationsProcessor.new
end
```

The callback code will be called after each find. It will use the same options as the find operation, without the
pagination, to collect the record count. This is stored in the `operation_meta`, which will be returned in the top level
meta element.

#### Namespaces

Railsapi::Resources supports namespacing of resources. With namespacing you can version your API.

#### Error codes

Error codes are provided for each error object returned, based on the error. These errors are:

```ruby
module JSONAPI
  VALIDATION_ERROR = '100'
  INVALID_RESOURCE = '101'
  FILTER_NOT_ALLOWED = '102'
  INVALID_FIELD_VALUE = '103'
  INVALID_FIELD = '104'
  PARAM_NOT_ALLOWED = '105'
  PARAM_MISSING = '106'
  INVALID_FILTER_VALUE = '107'
  COUNT_MISMATCH = '108'
  KEY_ORDER_MISMATCH = '109'
  KEY_NOT_INCLUDED_IN_URL = '110'
  INVALID_INCLUDE = '112'
  RELATION_EXISTS = '113'
  INVALID_SORT_CRITERIA = '114'
  INVALID_LINKS_OBJECT = '115'
  TYPE_MISMATCH = '116'
  INVALID_PAGE_OBJECT = '117'
  INVALID_PAGE_VALUE = '118'
  INVALID_FIELD_FORMAT = '119'
  INVALID_FILTERS_SYNTAX = '120'
  SAVE_FAILED = '121'
  FORBIDDEN = '403'
  RECORD_NOT_FOUND = '404'
  UNSUPPORTED_MEDIA_TYPE = '415'
  LOCKED = '423'
end
```

These codes can be customized in your app by creating an initializer to override any or all of the codes.

In addition textual error codes can be returned by setting the configuration option `use_text_errors = true`. For
example:

```ruby
JSONAPI.configure do |config|
  config.use_text_errors = true
end
```


#### Handling Exceptions

By default, all exceptions raised downstream from a resource controller will be caught, logged, and a ```500 Internal Server Error``` will be rendered. Exceptions can be whitelisted in the config to pass through the handler and be caught manually, or you can pass a callback from a resource controller to insert logic into the rescue block without interrupting the control flow. This can be particularly useful for additional logging or monitoring without the added work of rendering responses.

Pass a block, refer to controller class methods, or both. Note that methods must be defined as class methods on a controller and accept one parameter, which is passed the exception object that was rescued.

```ruby
  class ApplicationController < Railsapi::ResourceController

    on_server_error :first_callback

    #or

    # on_server_error do |error|
      #do things
    #end

    def self.first_callback(error)
      #env["airbrake.error_id"] = notify_airbrake(error)
    end
  end

```

#### Action Callbacks

##### ensure_correct_media_type

By default, when controllers extend functionalities from `railsapi-resources`, the `ActsAsResourceController#ensure_correct_media_type`
method will be triggered before `create`, `update`, `create_relationship` and `update_relationship` actions. This method is reponsible
for checking if client's request corresponds to the correct media type required by [JSON API](http://jsonapi.org/format/#content-negotiation-clients): `application/vnd.api+json`.

In case you need to check the media type for custom actions, just make sure to call the method in your controller's `before_action`:

```ruby
class UsersController < Railsapi::ResourceController
  before_action :ensure_correct_media_type, only: [:auth]

  def auth
    # some crazy auth code goes here
  end
end
```

#### Formatting

Railsapi Resources by default uses some simple rules to format (and unformat) an attribute for (de-)serialization. Strings and Integers are output to JSON
as is, and all other values have `.to_s` applied to them. This outputs something in all cases, but it is certainly not
correct for every situation.

If you want to change the way an attribute is (de-)serialized you have a couple of ways. The simplest method is to create a
getter (and setter) method on the resource which overrides the attribute and apply the (un-)formatting there. For example:

```ruby
class PersonResource < Railsapi::Resource
  attributes :name, :email, :last_login_time

  # Setter example
  def email=(new_email)
    @model.email = new_email.downcase
  end

  # Getter example
  def last_login_time
    @model.last_login_time.in_time_zone(@context[:current_user].time_zone).to_s
  end
end
```

This is simple to implement for a one off situation, but not for example if you want to apply the same formatting rules
to all DateTime fields in your system. Another issue is the attribute on the resource will always return a formatted
response, whether you want it or not.

##### Value Formatters

To overcome the above limitations Railsapi Resources uses Value Formatters. Value Formatters allow you to control the way values are
handled for an attribute. The `format` can be set per attribute as it is declared in the resource. For example:

```ruby
class PersonResource < Railsapi::Resource
  attributes :name, :email, :spoken_languages
  attribute :last_login_time, format: :date_with_utc_timezone

  # Getter/Setter for spoken_languages ...
end
```

A Value formatter has a `format` and an `unformat` method. Here's the base ValueFormatter and DefaultValueFormatter for
reference:

```ruby
module JSONAPI
  class ValueFormatter < Formatter
    class << self
      def format(raw_value)
        super(raw_value)
      end

      def unformat(value)
        super(value)
      end
      ...
    end
  end
end

class DefaultValueFormatter < Railsapi::ValueFormatter
  class << self
    def format(raw_value)
      case raw_value
        when String, Integer
          return raw_value
        else
          return raw_value.to_s
      end
    end
  end
end
```

You can also create your own Value Formatter. Value Formatters must be named with the `format` name followed by
`ValueFormatter`, i.e. `DateWithUTCTimezoneValueFormatter` and derive from `Railsapi::ValueFormatter`. It is
recommended that you create a directory for your formatters, called `formatters`.

The `format` method is called by the `ResourceSerializer` as is serializing a resource. The format method takes the
`raw_value` parameter. `raw_value` is the value as read from the model.

The `unformat` method is called when processing the request. Each incoming attribute (except `links`) are run through
the `unformat` method. The `unformat` method takes a `value`, which is the value as it comes in on the
request. This allows you process the incoming value to alter its state before it is stored in the model.

###### Use a Different Default Value Formatter

Another way to handle formatting is to set a different default value formatter. This will affect all attributes that do
not have a `format` set. You can do this by overriding the `default_attribute_options` method for a resource (or a base
resource for a system wide change).

```ruby
  def default_attribute_options
    {format: :my_default}
  end
```

and

```ruby
class MyDefaultValueFormatter < Railsapi::ValueFormatter
  class << self
    def format(raw_value)
      case raw_value
        when String, Integer
          return raw_value
        when DateTime
          return raw_value.in_time_zone('UTC').to_s
        else
          return raw_value.to_s
      end
    end
  end
end
```

This way all DateTime values will be formatted to display in the UTC timezone.

#### Key Format

By default Railsapi Resources uses dasherized keys as per the
[JSON API naming recommendations](http://jsonapi.org/recommendations/#naming).  This can be changed by specifying a
different key formatter.

For example, to use camel cased keys with an initial lowercase character (JSON's default) create an initializer and add
the following:

```ruby
JSONAPI.configure do |config|
  # built in key format options are :underscored_key, :camelized_key and :dasherized_key
  config.json_key_format = :camelized_key
end
```

This will cause the serializer to use the `CamelizedKeyFormatter`. You can also create your own `KeyFormatter`, for
example:

```ruby
class UpperCamelizedKeyFormatter < Railsapi::KeyFormatter
  class << self
    def format(key)
      super.camelize(:upper)
    end
  end
end
```


## Contributing

1. Fork it ( http://github.com/cerebris/railsapi-resources/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Copyright 2016 Cerebris Corporation. MIT License (see LICENSE for details).
