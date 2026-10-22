# frozen_string_literal: true

require 'test_helper'

# A new searchable must work without registering its name in any central list.
class Search::SearchableRegistrationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'reindex covers every model that includes Searchable' do
    assert_includes SearchReindexJob.searchable_models, Bullet
    assert_includes SearchReindexJob.searchable_models, Collection
  end

  test 'reindex picks up a searchable with no central registration' do
    with_searchable('Widget') do |model|
      assert_includes SearchReindexJob.searchable_models, model
    end
  end

  test 'bullet declares its own preload' do
    assert_equal %i[collection rich_text_body published_entity], Bullet.search_preload
  end

  test 'collection declares its own preload' do
    assert_empty Collection.search_preload
  end

  test 'a searchable with no declared preload preloads nothing' do
    with_searchable('Widget') do |model|
      assert_empty model.search_preload
    end
  end

  test 'a model that does not include Searchable is not registered' do
    assert_not_includes Searchable.searchable_models, User
  end

  private

  # Registers a throwaway searchable, then restores the registry so the model
  # cannot leak into other tests (SearchReindexJob walks every entry).
  def with_searchable(name)
    model = Class.new(ApplicationRecord) do
      define_singleton_method(:name) { name }
      include Searchable
    end

    yield model
  ensure
    Searchable.searchable_models.delete(model)
  end
end
