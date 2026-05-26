# frozen_string_literal: true

class CreateIssueKeysSchema < ActiveRecord::Migration[6.1]
  def up
    add_column :projects, :issue_key_prefix, :string, limit: 16 unless column_exists?(:projects, :issue_key_prefix)
    add_index :projects, :issue_key_prefix, unique: true, name: :idx_projects_issue_key_prefix unless index_exists?(:projects, :issue_key_prefix, name: :idx_projects_issue_key_prefix)

    add_column :issues, :project_issue_number, :integer unless column_exists?(:issues, :project_issue_number)
    add_column :issues, :issue_key, :string, limit: 32 unless column_exists?(:issues, :issue_key)
    add_index :issues, :issue_key, unique: true, name: :idx_issues_issue_key unless index_exists?(:issues, :issue_key, name: :idx_issues_issue_key)
    unless index_exists?(:issues, [:project_id, :project_issue_number], name: :idx_issues_project_issue_number)
      add_index :issues, [:project_id, :project_issue_number], unique: true, name: :idx_issues_project_issue_number
    end

    return if table_exists?(:project_issue_counters)

    create_table :project_issue_counters do |t|
      t.references :project, null: false, index: {unique: true, name: :idx_pic_project_id}
      t.integer :next_value, null: false, default: 1
      t.timestamps null: false
    end
  end

  def down
    drop_table :project_issue_counters if table_exists?(:project_issue_counters)

    remove_index :issues, name: :idx_issues_project_issue_number if index_exists?(:issues, [:project_id, :project_issue_number], name: :idx_issues_project_issue_number)
    remove_index :issues, name: :idx_issues_issue_key if index_exists?(:issues, :issue_key, name: :idx_issues_issue_key)
    remove_column :issues, :issue_key if column_exists?(:issues, :issue_key)
    remove_column :issues, :project_issue_number if column_exists?(:issues, :project_issue_number)

    remove_index :projects, name: :idx_projects_issue_key_prefix if index_exists?(:projects, :issue_key_prefix, name: :idx_projects_issue_key_prefix)
    remove_column :projects, :issue_key_prefix if column_exists?(:projects, :issue_key_prefix)
  end
end
