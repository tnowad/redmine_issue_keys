# frozen_string_literal: true

module RedmineIssueKeys
  module ApplicationHelperPatch
    ISSUE_KEY_RE = /\b([A-Z][A-Z0-9]{1,15}-\d+)\b/i

    def link_to_issue(issue, options = {})
      title = nil
      subject = nil
      display_id = options[:display_id].presence || issue.display_id
      text = options[:tracker] == false ? display_id : "#{issue.tracker} #{display_id}"
      if options[:subject] == false
        title = issue.subject.truncate(60)
      else
        subject = issue.subject
        subject = subject.truncate(options[:truncate]) if options[:truncate]
      end
      only_path = options[:only_path].nil? ? true : options[:only_path]
      s = link_to(text, issue_url(issue, only_path: only_path), class: issue.css_classes, title: title)
      s << h(": #{subject}") if subject
      s = h("#{issue.project} - ") + s if options[:project]
      s
    end

    def parse_redmine_links(text, default_project, obj, attr, only_path, options)
      html = super || text.dup
      fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
      modified = false

      fragment.xpath('.//text()[not(ancestor::a) and not(ancestor::pre) and not(ancestor::code)]').each do |node|
        node_text = node.text
        next unless node_text.match?(ISSUE_KEY_RE)

        replacement_nodes = []
        position = 0

        while (match = node_text.match(ISSUE_KEY_RE, position))
          start = match.begin(1)
          ending = match.end(1)

          replacement_nodes << Nokogiri::XML::Text.new(node_text[position...start], node.document) if start > position

          issue_key = match[1].upcase
          issue = Issue.visible.find_by(issue_key: issue_key)
          if issue
            modified = true
            link_fragment = Nokogiri::HTML5.fragment(
              link_to_issue(issue, only_path: only_path, tracker: true, subject: false, display_id: match[1])
            )
            replacement_nodes.concat(link_fragment.children.to_a)
          else
            replacement_nodes << Nokogiri::XML::Text.new(match[1], node.document)
          end

          position = ending
        end

        replacement_nodes << Nokogiri::XML::Text.new(node_text[position..], node.document) if position < node_text.length
        next if replacement_nodes.empty?

        replacement_nodes.reverse_each { |replacement_node| node.add_next_sibling(replacement_node) }
        node.remove
      end

      if modified || html != text
        text.replace(fragment.to_html)
      end
    end
  end
end
