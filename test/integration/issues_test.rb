# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class IssuesIntegrationTest < Redmine::IntegrationTest
    test 'GET /issues/:issue_key should work' do
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Integration issue key path')

      get "/issues/#{issue.issue_key}"

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug AUTH-1/
    end

    test 'GET /issues/:id should still work for numeric issue ids' do
      issue = Issue.find(1)

      get "/issues/#{issue.id}"

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug #1/
    end

    test 'GET /browse/:issue_key should work' do
      project = Project.generate!(:issue_key_prefix => 'AUTH')
      issue = Issue.generate!(:project => project, :subject => 'Browse integration issue key path')

      get "/browse/#{issue.issue_key}"

      assert_response :success
      assert_select 'h2.inline-block', :text => /Bug AUTH-1/
    end
  end
end
