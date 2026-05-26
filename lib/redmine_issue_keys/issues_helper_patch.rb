# frozen_string_literal: true

module RedmineIssueKeys
  module IssuesHelperPatch
    def issue_heading(issue)
      h("#{issue.tracker} #{issue.display_id}")
    end
  end
end
