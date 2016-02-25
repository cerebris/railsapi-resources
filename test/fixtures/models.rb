require 'active_record'
require 'railsapi-resources'

### DATABASE
ActiveRecord::Schema.define do
  create_table :people, force: true do |t|
    t.string     :name
    t.string     :email
    t.datetime   :date_joined
    t.belongs_to :preferences
    t.integer    :hair_cut_id, index: true
    t.boolean    :book_admin, default: false
    t.boolean    :special, default: false
    t.timestamps null: false
  end

  create_table :author_details, force: true do |t|
    t.integer :person_id
    t.string  :author_stuff
  end

  create_table :posts, force: true do |t|
    t.string     :title
    t.text       :body
    t.integer    :author_id
    t.belongs_to :section, index: true
    t.timestamps null: false
  end

  create_table :comments, force: true do |t|
    t.text       :body
    t.belongs_to :post, index: true
    t.integer    :author_id
    t.timestamps null: false
  end

  create_table :companies, force: true do |t|
    t.string     :type
    t.string     :name
    t.string     :address
    t.timestamps null: false
  end

  create_table :tags, force: true do |t|
    t.string :name
  end

  create_table :posts_tags, force: true do |t|
    t.references :post, :tag, index: true
  end
  add_index :posts_tags, [:post_id, :tag_id], unique: true

  create_table :comments_tags, force: true do |t|
    t.references :comment, :tag, index: true
  end

  create_table :preferences, force: true do |t|
    t.integer :person_id
    t.boolean :advanced_mode, default: false
  end

  create_table :books, force: true do |t|
    t.string :title
    t.string :isbn
    t.boolean :banned, default: false
  end

  create_table :book_authors, force: true do |t|
    t.integer :book_id
    t.integer :person_id
  end

  create_table :book_comments, force: true do |t|
    t.text       :body
    t.belongs_to :book, index: true
    t.integer    :author_id
    t.boolean    :approved, default: true
    t.timestamps null: false
  end

  create_table :numeros_telefone, force: true do |t|
    t.string   :numero_telefone
    t.timestamps null: false
  end
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  has_many :vehicles
  belongs_to :preferences
  belongs_to :hair_cut
  has_one :author_detail

  has_and_belongs_to_many :books, join_table: :book_authors

  ### Validations
  validates :name, presence: true
  validates :date_joined, presence: true
end

class AuthorDetail < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'person_id'
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :writer, class_name: 'Person', foreign_key: 'author_id'
  has_many :comments
  has_and_belongs_to_many :tags, join_table: :posts_tags
  has_many :special_post_tags, source: :tag
  has_many :special_tags, through: :special_post_tags, source: :tag
  belongs_to :section

  validates :author, presence: true
  validates :title, length: { maximum: 35 }

  before_destroy :destroy_callback

  def destroy_callback
    if title == "can't destroy me"
      errors.add(:title, "can't destroy me")

      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
    end
  end
end

class Comment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post
  has_and_belongs_to_many :tags, join_table: :comments_tags
end

class Company < ActiveRecord::Base
end

class Firm < Company
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, join_table: :posts_tags
  has_and_belongs_to_many :planets, join_table: :planets_tags
end

class Cat < ActiveRecord::Base
end

class Preferences < ActiveRecord::Base
  has_one :author, class_name: 'Person', :inverse_of => 'preferences'
end

class Book < ActiveRecord::Base
  has_many :book_comments
  has_many :approved_book_comments, -> { where(approved: true) }, class_name: "BookComment"

  has_and_belongs_to_many :authors, join_table: :book_authors, class_name: "Person"
end

class BookComment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :book

  def self.for_user(current_user)
    records = self
    # Hide the unapproved comments from people who are not book admins
    unless current_user && current_user.book_admin
      records = records.where(approved: true)
    end
    records
  end
end

class NumeroTelefone < ActiveRecord::Base
end
