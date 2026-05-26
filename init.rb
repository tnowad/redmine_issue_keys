require 'pathname'

Redmine::Plugin.register :redmine_issue_keys do
  name 'Redmine Issue Keys'
  author 'Redmine Issue Keys'
  description 'Adds Jira-style issue keys while preserving numeric IDs'
  version '0.1.0'
  requires_redmine version_or_higher: '6.0.0'
end

plugin_root = Pathname.new(__dir__)
plugin_views = plugin_root.join('app', 'views').to_s

module RedmineIssueKeys
  def self.normalize_issue_query_columns!
    columns = IssueQuery.available_columns
    return unless columns.count {|column| column.name == :issue_key} > 1

    seen = {}
    IssueQuery.available_columns = columns.each_with_object([]) do |column, normalized|
      next if seen[column.name]

      seen[column.name] = true
      normalized << column
    end
  end
end

%w[
  project_issue_counter
  redmine_issue_keys/project_patch
  redmine_issue_keys/issue_patch
  redmine_issue_keys/issues_helper_patch
  redmine_issue_keys/application_controller_patch
  redmine_issue_keys/application_helper_patch
  redmine_issue_keys/auto_completes_controller_patch
  redmine_issue_keys/issue_query_patch
  redmine_issue_keys/changeset_patch
  redmine_issue_keys/repositories_controller_patch
  redmine_issue_keys/repositories_helper_patch
  redmine_issue_keys/search_controller_patch
  redmine_issue_keys/project_form_hook
].each do |file|
  require plugin_root.join('lib', file).to_s
end

apply_redmine_issue_keys_patches = lambda do
  ActionController::Base.prepend_view_path(plugin_views) unless ActionController::Base.view_paths.map(&:to_s).include?(plugin_views)

  Project.prepend RedmineIssueKeys::ProjectPatch unless Project < RedmineIssueKeys::ProjectPatch
  Issue.prepend RedmineIssueKeys::IssuePatch unless Issue < RedmineIssueKeys::IssuePatch
  IssuesHelper.prepend RedmineIssueKeys::IssuesHelperPatch unless IssuesHelper < RedmineIssueKeys::IssuesHelperPatch
  ApplicationController.prepend RedmineIssueKeys::ApplicationControllerPatch unless ApplicationController < RedmineIssueKeys::ApplicationControllerPatch
  ApplicationHelper.prepend RedmineIssueKeys::ApplicationHelperPatch unless ApplicationHelper < RedmineIssueKeys::ApplicationHelperPatch
  AutoCompletesController.prepend RedmineIssueKeys::AutoCompletesControllerPatch unless AutoCompletesController < RedmineIssueKeys::AutoCompletesControllerPatch
  IssueQuery.prepend RedmineIssueKeys::IssueQueryPatch unless IssueQuery < RedmineIssueKeys::IssueQueryPatch
  Changeset.prepend RedmineIssueKeys::ChangesetPatch unless Changeset < RedmineIssueKeys::ChangesetPatch
  RepositoriesController.prepend RedmineIssueKeys::RepositoriesControllerPatch unless RepositoriesController < RedmineIssueKeys::RepositoriesControllerPatch
  RepositoriesHelper.prepend RedmineIssueKeys::RepositoriesHelperPatch unless RepositoriesHelper < RedmineIssueKeys::RepositoriesHelperPatch
  SearchController.prepend RedmineIssueKeys::SearchControllerPatch unless SearchController < RedmineIssueKeys::SearchControllerPatch
  RedmineIssueKeys.normalize_issue_query_columns!
end

if Rails.application.reloader.respond_to?(:to_prepare)
  Rails.application.reloader.to_prepare(&apply_redmine_issue_keys_patches)
else
  ActiveSupport::Reloader.to_prepare(&apply_redmine_issue_keys_patches)
end

apply_redmine_issue_keys_patches.call
