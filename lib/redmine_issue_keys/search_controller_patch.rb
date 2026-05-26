# frozen_string_literal: true

module RedmineIssueKeys
  module SearchControllerPatch
    def index
      if !api_request? && params[:q].to_s.match?(/\A[A-Z][A-Z0-9]{1,15}-\d+\z/i)
        issue = Issue.visible.find_by(issue_key: params[:q].to_s.upcase)
        flash[:notice] = l(:notice_search_redirect_to_issue, issue_key: issue.issue_key)
        return redirect_to(issue_path(issue)) if issue
      end
      super
    end
  end
end
