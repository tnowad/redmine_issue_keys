# frozen_string_literal: true

require_relative '../../test_helper'

module RedmineIssueKeys
  class ApiIssuesTest < Redmine::ApiTest::Base
    test 'GET /issues/:issue_key.xml should include id, issue_key, and project_issue_number' do
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'API issue')

      get "/issues/#{issue.issue_key}.xml"

      assert_response :success
      assert_select 'issue id', :text => issue.id.to_s
      assert_select 'issue issue_key', :text => issue.issue_key
      assert_select 'issue project_issue_number', :text => issue.project_issue_number.to_s
    end

    test 'GET /issues.xml should include id, issue_key, and project_issue_number' do
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'API issue')

      get '/issues.xml'

      assert_response :success
      assert_select 'issues issue:first-child id', :text => issue.id.to_s
      assert_select 'issues issue:first-child issue_key', :text => issue.issue_key
      assert_select 'issues issue:first-child project_issue_number', :text => issue.project_issue_number.to_s
    end
  end
end
