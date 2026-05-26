# frozen_string_literal: true

module RedmineIssueKeys
  module RepositoriesHelperPatch
    ISSUE_KEY_RE = /\b([A-Z][A-Z0-9]{1,15}-\d+)\b/i

    def linkify_repository_ref_issue_keys(text)
      value = text.to_s
      return ERB::Util.h(value) if value.blank?

      parts = []
      position = 0

      while (match = value.match(ISSUE_KEY_RE, position))
        start = match.begin(1)
        ending = match.end(1)
        parts << ERB::Util.h(value[position...start]) if start > position

        issue = Issue.visible.find_by(issue_key: match[1].upcase)
        if issue
          parts << link_to_issue(issue, only_path: true, tracker: false, subject: false, display_id: match[1])
        else
          parts << ERB::Util.h(match[1])
        end

        position = ending
      end

      parts << ERB::Util.h(value[position..]) if position < value.length
      safe_join(parts)
    end
  end
end
