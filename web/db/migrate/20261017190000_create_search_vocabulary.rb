# frozen_string_literal: true

# Exposes existing indexed words without storing or maintaining another word list.
class CreateSearchVocabulary < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table :search_vocabulary, :fts5vocab, %w[search_records_fts5 row]
  end
end
