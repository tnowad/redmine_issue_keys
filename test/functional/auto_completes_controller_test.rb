# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class AutoCompletesControllerTest < ActionController::TestCase
    tests AutoCompletesController

    def setup
      super
      User.current = nil
      @request.session[:user_id] = 2
    end

    def test_issues_finds_issue_by_issue_key
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Issue key autocomplete')

      get(
        :issues,
        :params => {
          :project_id => project.identifier,
          :q => issue.issue_key
        }
      )

      assert_response :success
      json = ActiveSupport::JSON.decode(response.body)
      assert_equal issue.id, json.first['id']
      assert_equal issue.issue_key, json.first['value']
      assert_include issue.issue_key, json.first['label']
    end

    def test_issues_finds_issue_by_lowercase_issue_key
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Lowercase key autocomplete')

      get(
        :issues,
        :params => {
          :project_id => project.identifier,
          :q => issue.issue_key.downcase
        }
      )

      assert_response :success
      json = ActiveSupport::JSON.decode(response.body)
      assert_equal issue.id, json.first['id']
      assert_equal issue.issue_key, json.first['value']
    end
  end
end
