# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class RepositoriesControllerTest < Redmine::RepositoryControllerTest
    tests RepositoriesController

    def setup
      super
      User.current = nil
      @request.session[:user_id] = 2
      @project = Project.find(1)
      @project.update_columns(:issue_key_prefix => 'AUTH')
    end

    def test_add_related_issue_accepts_issue_key
      issue = Issue.generate!(:project => @project, :subject => 'Issue key relation')

      assert_difference 'Changeset.find(103).issues.size' do
        post(
          :add_related_issue,
          :params => {
            :id => 1,
            :repository_id => 10,
            :rev => 4,
            :issue_id => issue.issue_key,
            :format => 'js'
          },
          :xhr => true
        )
      end

      assert_response :success
      assert_includes Changeset.find(103).issue_ids, issue.id
      assert_include issue.issue_key, response.body
    end

    def test_revision_related_issue_form_accepts_issue_key_ui
      Role.find(1).add_permission! :manage_related_issues

      get(
        :revision,
        :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 1
        }
      )

      assert_response :success
      assert_select 'form#new-relation-form' do
        assert_select 'input[name=?][placeholder=?]', 'issue_id', 'AUTH-1'
      end
      assert_no_match(/Issue #/, response.body)
    end

    def test_add_related_issue_accepts_lowercase_issue_key
      issue = Issue.generate!(:project => @project, :subject => 'Lowercase issue key relation')

      assert_difference 'Changeset.find(103).issues.size' do
        post(
          :add_related_issue,
          :params => {
            :id => 1,
            :repository_id => 10,
            :rev => 4,
            :issue_id => issue.issue_key.downcase,
            :format => 'js'
          },
          :xhr => true
        )
      end

      assert_response :success
      assert_includes Changeset.find(103).issue_ids, issue.id
    end

  end
end
