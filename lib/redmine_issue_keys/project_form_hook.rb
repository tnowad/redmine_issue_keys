# frozen_string_literal: true

module RedmineIssueKeys
  class ProjectFormHook < Redmine::Hook::ViewListener
    render_on :view_projects_form, partial: 'redmine_issue_keys/projects/form'
  end
end
