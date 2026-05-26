# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class IssuesControllerTest < Redmine::ControllerTest
    tests IssuesController

    def setup
      User.current = nil
    end

    def test_show_should_work_for_issue_key_path
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Browse me')

      get :show, :params => {:issue_key => issue.issue_key}

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug AUTH-1/
    end

    def test_show_should_work_for_lowercase_issue_key_path
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Browse me lowercase')

      get :show, :params => {:issue_key => issue.issue_key.downcase}

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug AUTH-1/
    end

    def test_show_should_work_for_issue_key_in_id_path
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Browse me by id path')

      get :show, :params => {:id => issue.issue_key}

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug AUTH-1/
    end

    def test_show_should_return_404_for_missing_issue_key
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      Issue.generate!(:project => project, :subject => 'Browse me')

      get :show, :params => {:issue_key => 'AUTH-999'}

      assert_response :not_found
    end

    def test_show_should_return_404_for_invalid_issue_key
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      Issue.generate!(:project => project, :subject => 'Browse me invalid')

      get :show, :params => {:id => 'not-a-key'}

      assert_response :not_found
    end

    def test_show_should_keep_numeric_issue_paths_working
      get :show, :params => {:id => 1}

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug #1/
    end
  end
end
