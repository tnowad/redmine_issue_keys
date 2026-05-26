# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class IssueQueryKeysTest < ActiveSupport::TestCase
    def setup
      User.current = nil
    end

    def test_issue_key_filter_is_available
      query = IssueQuery.new(:project => Project.find(1), :name => '_')

      assert query.available_filters.key?('issue_key')
      assert query.available_columns.any? {|column| column.name == :issue_key}
    end

    def test_issue_key_is_in_default_columns_like_issue_id
      query = IssueQuery.new(:project => Project.find(1), :name => '_')

      assert_equal [:id, :issue_key], query.columns.first(2).map(&:name)
    end

    def test_issue_key_filter_normalizes_values
      query = IssueQuery.new(:project => Project.find(1), :name => '_')

      sql = query.sql_for_issue_key_field('issue_key', '=', ['auth-1'])

      assert_include 'AUTH-1', sql
    end

    def test_issue_key_columns_are_deduplicated_after_reload
      original_columns = IssueQuery.available_columns.dup
      duplicate_issue_key = original_columns.select {|column| column.name == :issue_key}

      IssueQuery.available_columns = original_columns + duplicate_issue_key

      RedmineIssueKeys.normalize_issue_query_columns!

      assert_equal 1, IssueQuery.available_columns.count {|column| column.name == :issue_key}
    ensure
      IssueQuery.available_columns = original_columns if original_columns
    end
  end
end
