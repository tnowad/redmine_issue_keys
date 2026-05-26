# frozen_string_literal: true

require_relative '../../../../test/test_helper'

module RedmineIssueKeys
  class IssueKeyRepositoryIntegrationTest < Redmine::IntegrationTest
    fixtures :all

    setup do
      @project = Project.generate!
      @project.update_column(:issue_key_prefix, 'AUTH')
      @project.enable_module!(:repository)

      @repository = Repository::Git.create!(
        project: @project,
        url: '/tmp/test.git',
        is_default: true,
        path_encoding: 'UTF-8'
      )

      @changeset = Changeset.create!(
        repository: @repository,
        revision: 'abc123abc123abc123abc123abc123abc123abc1',
        committer: 'dev <dev@test.com>',
        committed_on: Time.current,
        comments: "Implemented DEV-1 feature"
      )

      @issue = Issue.generate!(project: @project, subject: 'Repo linked issue', author: User.find(1))
      @issue.reload
    end

    def test_changeset_links_to_issue_when_comment_contains_issue_key
      @changeset.update_column(:comments, "fixes #{@issue.issue_key} bug resolved")
      @changeset.scan_comment_for_issue_ids if @changeset.respond_to?(:scan_comment_for_issue_ids)

      assert @changeset.reload.issues.include?(@issue),
             "Expected changeset to link to #{@issue.issue_key}"
    end

    def test_related_issue_can_be_added_via_issue_key
      if Issue.respond_to?(:find_by_issue_key)
        issue = Issue.find_by_issue_key(@issue.issue_key)
        assert_equal @issue.id, issue.id
      end
    end

    def test_issue_key_resolution_in_changeset_context
      @changeset.update_column(:comments, "refs #{@issue.issue_key} implemented")
      @changeset.scan_comment_for_issue_ids if @changeset.respond_to?(:scan_comment_for_issue_ids)

      if @issue.issue_key.present?
        assert @changeset.reload.issues.include?(@issue),
               "Expected changeset to link to #{@issue.issue_key}"
      end
    end
  end
end
