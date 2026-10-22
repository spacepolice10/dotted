# frozen_string_literal: true

class SplitMultiImageBullets < ActiveRecord::Migration[8.1]
  def up
    rows = connection.select_all(<<~SQL)
      SELECT attachments.id, attachments.record_id, blobs.filename
      FROM active_storage_attachments AS attachments
      JOIN active_storage_blobs AS blobs ON blobs.id = attachments.blob_id
      WHERE attachments.record_type = 'Bullet' AND attachments.name = 'images'
      ORDER BY attachments.record_id, attachments.id
    SQL

    rows.group_by { |row| row['record_id'] }.each do |bullet_id, images|
      bullet = connection.select_one("SELECT * FROM bullets WHERE id = #{quote(bullet_id)}")
      raise "Missing bullet #{bullet_id} for attached images" unless bullet
      if connection.select_value(<<~SQL).to_i.positive?
        SELECT COUNT(*) FROM active_storage_attachments
        WHERE record_type = 'Bullet' AND record_id = #{quote(bullet_id)} AND name = 'file'
      SQL
        raise "Bullet #{bullet_id} already has a file attachment"
      end

      images.each_with_index do |image, index|
        filename = image.fetch('filename')
        target_id = index.zero? ? bullet_id : create_file_bullet(bullet, filename)
        connection.execute(<<~SQL)
          UPDATE active_storage_attachments
          SET name = 'file', record_id = #{quote(target_id)}
          WHERE id = #{quote(image.fetch('id'))}
        SQL
        if index.zero?
          connection.execute("UPDATE bullets SET filename = #{quote(filename)} WHERE id = #{quote(bullet_id)}")
          connection.execute(<<~SQL)
            UPDATE search_records
            SET search_name = #{quote(filename)}, search_body = #{quote(filename)}
            WHERE searchable_type = 'Bullet' AND searchable_id = #{quote(bullet_id)}
          SQL
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'The original image groups cannot be reconstructed'
  end

  private

  def create_file_bullet(source, filename)
    fields = %w[user_id pops_on done_at author_name created_at updated_at collection_id last_postponed_at postponements_number]
    values = fields.map { |field| quote(source[field]) }
    id = connection.insert(<<~SQL)
      INSERT INTO bullets (#{(fields + ['filename']).join(', ')})
      VALUES (#{(values + [quote(filename)]).join(', ')})
    SQL
    return id if source['done_at']

    now = quote(Time.current)
    connection.execute(<<~SQL)
      INSERT INTO search_records
        (user_id, searchable_type, searchable_id, search_name, search_body, created_at, updated_at)
      VALUES
        (#{quote(source['user_id'])}, 'Bullet', #{quote(id)}, #{quote(filename)}, #{quote(filename)}, #{now}, #{now})
    SQL
    id
  end
end
