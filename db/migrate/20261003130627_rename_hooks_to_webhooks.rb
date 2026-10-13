# frozen_string_literal: true

class RenameHooksToWebhooks < ActiveRecord::Migration[8.1]
  def change
    rename_table :hooks, :webhooks
  end
end
