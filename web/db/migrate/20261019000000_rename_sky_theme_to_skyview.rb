# frozen_string_literal: true

class RenameSkyThemeToSkyview < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE user_settings
      SET appearance = 'kazakstans_skyview'
      WHERE appearance = 'kazakstans_sky'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE user_settings
      SET appearance = 'kazakstans_sky'
      WHERE appearance = 'kazakstans_skyview'
    SQL
  end
end
