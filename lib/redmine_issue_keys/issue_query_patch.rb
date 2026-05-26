# frozen_string_literal: true

module RedmineIssueKeys
  module IssueQueryPatch
    def self.prepended(base)
      base.available_columns = base.available_columns + [
        QueryColumn.new(:issue_key, sortable: "#{Issue.table_name}.issue_key", caption: :field_issue_key, frozen: true)
      ]
    end

    def initialize_available_filters
      super
      add_available_filter('issue_key', type: :string, label: :field_issue_key) unless available_filters.key?('issue_key')
    end

    def sql_for_issue_key_field(field, operator, value)
      normalized = value.map { |v| v.to_s.upcase }
      sql_for_field('issue_key', operator, normalized, Issue.table_name, 'issue_key')
    end
  end
end
