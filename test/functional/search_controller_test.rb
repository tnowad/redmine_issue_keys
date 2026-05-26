# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class SearchControllerTest < Redmine::ControllerTest
    tests SearchController

    def setup
      User.current = nil
    end

    def test_exact_issue_key_query_should_redirect_to_issue
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Search redirect')

      get :index, :params => {:q => issue.issue_key}

      assert_response :found
      assert_redirected_to issue_path(issue)
    end

    def test_exact_issue_key_query_should_not_redirect_in_api
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Search api redirect')

      get :index, :params => {:q => issue.issue_key, :format => 'json'}

      assert_response :success
      assert_nil @response.location
      assert_match /"results"/, @response.body
    end

    def test_lowercase_issue_key_query_should_redirect_to_issue
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Search redirect lowercase')

      get :index, :params => {:q => issue.issue_key.downcase}

      assert_response :found
      assert_redirected_to issue_path(issue)
    end
  end
end
