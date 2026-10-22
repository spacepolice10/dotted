# frozen_string_literal: true

class RenameHooksToWebhooks < ActiveRecord::Migration[8.1]
  def up
    # Early databases created webhooks directly in CreateSchema.
    rename_table :hooks, :webhooks if table_exists?(:hooks)
  end

  def down
    rename_table :webhooks, :hooks if table_exists?(:webhooks)
  end
end
