# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class ProjectsControllerTest < Redmine::ControllerTest
    tests ProjectsController

    def setup
      User.current = nil
      @request.session[:user_id] = 1
    end

    def test_create_should_reject_duplicate_issue_key_prefix
      Project.generate!(:issue_key_prefix => 'AUTH')

      assert_no_difference 'Project.count' do
        post(
          :create,
          :params => {
            :project => new_project_params(:issue_key_prefix => 'auth')
          }
        )
      end

      assert_response :success
      assert_select_error 'Prefix has already been taken'
    end

    def test_create_should_reject_invalid_issue_key_prefixes
      ['A', '1AUTH', 'AU-TH'].each_with_index do |prefix, index|
        assert_no_difference 'Project.count' do
          post(
            :create,
            :params => {
              :project => new_project_params(
                :name => "invalid-prefix-#{index}",
                :identifier => "invalid-prefix-#{index}",
                :issue_key_prefix => prefix
              )
            }
          )
        end

        assert_response :success
        assert_select_error 'Prefix is invalid'
      end
    end

    private

    def new_project_params(overrides = {})
      suffix = "#{Process.pid}-#{Time.now.to_i}-#{overrides[:name] || 'project'}"

      {
        :name => "issue-key-prefix-#{suffix}",
        :identifier => "issue-key-prefix-#{suffix}"
      }.merge(overrides)
    end
  end
end
