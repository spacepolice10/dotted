# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  # Every including model registers itself here. Rails 8 no longer tracks
  # descendants without the descendants_tracker gem, so the concern keeps its
  # own list and a new searchable needs no central registry.
  @searchable_models = []

  class << self
    attr_reader :searchable_models

    # Only real tables belong in the registry: an abstract ancestor shares its
    # subclass's table, so Bullet::Searchable must not register alongside Bullet.
    def register(model)
      return unless model.is_a?(Class) && model < ApplicationRecord
      return if model.name.blank? || model.base_class != model

      searchable_models << model unless searchable_models.include?(model)
    end
  end

  included do
    # Associations to eager-load when this record comes back from the index.
    # Declared per model so adding a searchable needs no central registry.
    class_attribute :search_preload, default: [], instance_accessor: false

    Searchable.register(self)

    after_create_commit :create_in_search_index
    after_update_commit :update_in_search_index
    after_destroy_commit :remove_from_search_index
  end

  def reindex
    update_in_search_index
  end

  def destroy
    forget_search_selections!
    super
  end

  def forget_search_selections!
    Search::Selection.where(searchable_type: self.class.name, searchable_id: id).delete_all
  end

  private

  def create_in_search_index
    Search::Record.upsert!(search_record_attributes) if searchable?
  end

  def update_in_search_index
    if searchable?
      Search::Record.upsert!(search_record_attributes)
    else
      remove_from_search_index
    end
  end

  def remove_from_search_index
    Search::Record.find_by(
      searchable_type: self.class.name,
      searchable_id: id
    )&.destroy
  end

  def search_record_attributes
    {
      user_id: search_user_id,
      searchable_type: self.class.name,
      searchable_id: id,
      search_name: search_name,
      search_body: search_record_body
    }
  end

  def search_record_body
    search_body&.truncate_bytes(Search::Record::SEARCH_CONTENT_SIZE, omission: '')
  end

  def searchable?
    true
  end

  def search_name
    respond_to?(:name) ? name : "#{self.class.name} ##{id}"
  end

  def search_body
    [try(:name), try(:description), try(:body)].compact.join(' ')
  end

  def search_user_id
    user_id
  end
end
