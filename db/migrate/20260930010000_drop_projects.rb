# frozen_string_literal: true

class DropProjects < ActiveRecord::Migration[8.1]
  PROJECT_CONTENT_TYPE = 'application/vnd.actiontext.mention.project'

  def up
    # FTS stays in sync via search_records triggers (external-content FTS5).
    execute "DELETE FROM search_records WHERE searchable_type = 'Project'"
    execute "DELETE FROM search_selections WHERE searchable_type = 'Project'"
    execute <<~SQL.squish
      DELETE FROM activities
      WHERE subject_type = 'Project' OR action IN ('project_mentioned', 'project_unmentioned')
    SQL

    flatten_project_mentions

    drop_table :bullet_projects
    drop_table :projects
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def flatten_project_mentions
    select_rows(<<~SQL.squish).each do |id, body|
      SELECT id, body FROM action_text_rich_texts WHERE body LIKE '%#{PROJECT_CONTENT_TYPE}%'
    SQL
      fragment = Nokogiri::HTML5.fragment(body)
      fragment.css("action-text-attachment[content-type='#{PROJECT_CONTENT_TYPE}']").each do |node|
        label = Nokogiri::HTML5.fragment(node['content'].to_s).text.strip
        label = "##{label}" unless label.empty? || label.start_with?('#')
        node.replace(Nokogiri::XML::Text.new(label, fragment.document))
      end

      update("UPDATE action_text_rich_texts SET body = #{quote(fragment.to_html)} WHERE id = #{id.to_i}")
    end
  end
end
