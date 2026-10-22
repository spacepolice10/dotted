# frozen_string_literal: true

# Completions replace archives: archived-but-not-done bullets become done
# (preserving the archive date), archived collections are hard-destroyed
# (member bullets survive untagged), then the archives table goes away.
class DropArchivesBackfillDone < ActiveRecord::Migration[8.1]
  def up
    archived_collections = <<~SQL.squish
      SELECT archivable_id FROM archives WHERE archivable_type = 'Collection'
    SQL

    # 1. Untag bullets in archived collections (FK-safe before collection delete).
    execute <<~SQL.squish
      DELETE FROM bullet_collections WHERE collection_id IN (#{archived_collections})
    SQL

    # 2. Drop search rows pointing at archived collections.
    execute <<~SQL.squish
      DELETE FROM search_records
      WHERE searchable_type = 'Collection' AND searchable_id IN (#{archived_collections})
    SQL
    execute <<~SQL.squish
      DELETE FROM search_selections
      WHERE searchable_type = 'Collection' AND searchable_id IN (#{archived_collections})
    SQL

    # 3. Hard-destroy archived collections.
    execute <<~SQL.squish
      DELETE FROM collections WHERE id IN (#{archived_collections})
    SQL

    # 4. Archived-but-not-done bullets become done, keeping the archive date.
    execute <<~SQL.squish
      UPDATE bullets
      SET done_at = (
        SELECT archives.created_at FROM archives
        WHERE archives.archivable_type = 'Bullet'
          AND archives.archivable_id = bullets.id
      )
      WHERE done_at IS NULL AND EXISTS (
        SELECT 1 FROM archives
        WHERE archives.archivable_type = 'Bullet'
          AND archives.archivable_id = bullets.id
      )
    SQL

    # 5. Done bullets are not searchable: clear their search rows and selections.
    execute <<~SQL.squish
      DELETE FROM search_records
      WHERE searchable_type = 'Bullet'
        AND searchable_id IN (SELECT id FROM bullets WHERE done_at IS NOT NULL)
    SQL
    execute <<~SQL.squish
      DELETE FROM search_selections
      WHERE searchable_type = 'Bullet'
        AND searchable_id IN (SELECT id FROM bullets WHERE done_at IS NOT NULL)
    SQL

    # 6. Drop the archives table.
    drop_table :archives
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
