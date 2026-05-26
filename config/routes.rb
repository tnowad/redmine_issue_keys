get '/browse/:issue_key', to: 'issues#show', as: 'browse_issue', constraints: {issue_key: /[A-Z][A-Z0-9]{1,15}-\d+/i}
