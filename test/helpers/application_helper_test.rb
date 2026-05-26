# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueKeys
  class ApplicationHelperTest < Redmine::HelperTest
    include ApplicationHelper
    include RepositoriesHelper

    def setup
      super
      @project = Project.find(1)
    end

    def test_link_to_issue_uses_issue_key_display_id
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      issue = Issue.generate!(:project => project, :subject => 'Rendered key ' + ('x' * 80))

      expected_title = issue.subject.truncate(60)
      result = link_to_issue(issue, :subject => false, :tracker => false)

      assert_select_in result, "a[href=?][title=?]", "/issues/#{issue.id}", expected_title, :text => issue.display_id
    end

    def test_textilizable_keeps_escaped_issue_keys_escaped
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      Issue.generate!(:project => project, :subject => 'Escaped key')

      with_settings :text_formatting => 'textile' do
        result = textilizable('Escaped &lt;AUTH-1&gt;')

        assert_match /&lt;/, result
        assert_match /&gt;/, result
        assert_no_match /<AUTH-1>/, result
        assert_select_in result, 'p', :text => /Escaped <.*AUTH-1>/
      end
    end

    def test_textilizable_does_not_nest_existing_issue_anchors
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      issue = Issue.generate!(:project => project, :subject => 'Nested anchor')
      raw = %("#{issue.issue_key}":http://example.com)

      with_settings :text_formatting => 'textile' do
        assert_equal %(<p><a href="http://example.com" class="external">#{issue.issue_key}</a></p>), textilizable(raw)
      end
    end

    def test_textilizable_links_lowercase_and_mixed_case_issue_keys
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      issue = Issue.generate!(:project => project, :subject => 'Case-preserved key')
      raw = "#{issue.issue_key} auth-1 Auth-1"

      with_settings :text_formatting => 'textile' do
        result = textilizable(raw)

        assert_select_in result, 'a', :text => "#{issue.tracker} #{issue.issue_key}"
        assert_select_in result, 'a', :text => "#{issue.tracker} auth-1"
        assert_select_in result, 'a', :text => "#{issue.tracker} Auth-1"
      end
    end

    def test_textilizable_skips_issue_keys_inside_code_and_pre
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      Issue.generate!(:project => project, :subject => 'Skipped key')
      raw = <<~RAW
        <pre>
        AUTH-1
        </pre>

        @AUTH-1@
      RAW

      with_settings :text_formatting => 'textile' do
        result = textilizable(raw)
        assert_select_in result, 'pre', :text => /AUTH-1/
        assert_select_in result, 'pre a', 0
        assert_select_in result, 'code', :text => /AUTH-1/
        assert_select_in result, 'code a', 0
      end
    end

    def test_linkify_repository_ref_issue_keys_links_embedded_issue_key
      project = Project.generate!(:issue_key_prefix => 'AUTH') { |p| p.parent = Project.find(1) }
      issue = Issue.generate!(:project => project, :subject => 'Repository ref key')

      result = linkify_repository_ref_issue_keys("feature/#{issue.issue_key}-login")

      assert_select_in result, 'a', :text => issue.issue_key
      assert_select_in result, "a[href=?]", "/issues/#{issue.id}"
      assert_match(/feature\//, result)
      assert_match(/-login/, result)
    end
  end
end
