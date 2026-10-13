# frozen_string_literal: true

require 'test_helper'

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test 'landing page is available without authentication' do
    get landing_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="preconnect"][href="https://fonts.gstatic.com"]', count: 1
    assert_select 'link[rel="stylesheet"][href^="/assets/"]', count: 11
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="typography"]', count: 1
    assert_select 'h1.branding-heading', text: 'dotted', count: 1
    assert_select 'link[rel="stylesheet"][href*="/card-"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="/pressable-"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="domain/search"]', count: 0
    assert_select 'script', count: 0
    assert_select 'body > header.landing-header .landing-menu-toggle[type="checkbox"]', count: 1
    assert_select 'header.landing-header nav[aria-label="Product"] a', count: 3
    assert_select 'header.landing-header nav[aria-label="Product"] a[href=?]', terminal_path, text: 'CLI & Agents'
    assert_select 'header.landing-header nav[aria-label="Product"] a[href=?]', once_path, count: 0
    assert_select 'header.landing-header nav[aria-label="Product"] a[href=?]', support_path, count: 0

    csp = response.headers.fetch('Content-Security-Policy')
    assert_includes csp, "default-src 'none'"
    assert_includes csp, "connect-src 'self'"
    assert_includes csp, "style-src 'self' https://fonts.googleapis.com"
    assert_includes csp, "style-src-attr 'unsafe-inline'"
    assert_includes csp, "frame-ancestors 'none'"
    assert_not_includes csp, 'script-src'
  end

  test 'features page uses the landing layout and security policy' do
    get features_path

    assert_response :success
    assert_no_match 'Rapid logging', response.body
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'body > header.landing-header', count: 1
    assert_select 'main[data-page="features"] > header.landing-heading h1', text: 'Features'
    assert_select 'main[data-page="features"] > .empty-state h2', text: 'Coming soon'
    assert_select 'main[data-page="features"] > .empty-state p', text: /Dotted’s features/
    assert_select 'main[data-page="features"] article', count: 0
    assert_select 'header.landing-header a[href=?]', landing_path
    assert_includes response.headers.fetch('Content-Security-Policy'), "default-src 'none'"
  end

  test 'terminal page is public and previews CLI and agent workflows' do
    get terminal_path

    assert_response :success
    assert_select 'title', text: 'CLI & Agents — Dotted'
    assert_select 'main[data-page="terminal"][data-size="md"]', count: 1
    assert_select 'section.terminal-card h1', text: 'Your journal, from the terminal.'
    assert_select 'section.terminal-card .terminal-card-kicker', count: 0
    assert_select '.terminal-session[aria-label="Illustrative agent session"]', count: 1
    assert_select '.terminal-session', text: /codex/
    assert_select '.terminal-session .terminal-response', text: /Added “Review project notes” to your daylog.*Tomorrow you have/
    assert_select '.terminal-card-intro', text: /Use the Dotted CLI/
    assert_select '.terminal-capabilities li', count: 5
    assert_select '.terminal-capabilities a[href=?]', 'https://github.com/spacepolice10/digibujo'
    assert_includes response.headers.fetch('Content-Security-Policy'), "default-src 'none'"
  end

  test 'old agents URL redirects to terminal page' do
    get '/agents'

    assert_redirected_to terminal_path
  end

  test 'support page uses the landing layout and security policy' do
    get support_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'body > main[data-page="support"]', count: 1
    assert_select 'main[data-page="support"] > header.landing-heading h1', text: 'Support'
    assert_select 'body > header.landing-header', count: 1
    assert_select 'header.landing-header a[href=?]', landing_path
    assert_select 'a[href=?]', 'mailto:naysdemo@zohomail.com'
    assert_select 'a[href=?]', 'https://github.com/spacepolice10/digibujo'
    assert_includes response.headers.fetch('Content-Security-Policy'), "default-src 'none'"
  end

  test 'once page links to installation resources and uses the landing layout' do
    get once_path

    assert_response :success
    assert_select 'html[lang="en"]', count: 1
    assert_select 'body > header.landing-header', count: 1
    assert_select 'main[data-page="once"][data-size="md"]', count: 1
    assert_select 'section.once-card h1', text: /Dotted.*ONCE-ready/, count: 1
    assert_select 'section.once-card ul[data-layout="column"][data-divider="single"] li', count: 2
    assert_select 'section.once-card a[href=?]', 'https://once.com/', text: 'Explore ONCE'
    assert_select 'section.once-card a[href=?]', 'https://github.com/spacepolice10/digibujo#install-with-once', text: 'Read Dotted installation instructions'
    assert_select 'pre code', count: 0
    assert_select 'link[rel="stylesheet"][href*="landing"]', count: 1
    assert_select 'script', count: 0
  end

  test 'header markup is the same for phone user agents' do
    get landing_path
    desktop_header = css_select('header.landing-header').first.to_html

    get landing_path, headers: { 'User-Agent' => 'iPhone' }

    assert_response :success
    assert_equal desktop_header, css_select('header.landing-header').first.to_html
  end

  test 'all landing pages have the same navigation header' do
    get landing_path
    landing_header = css_select('header.landing-header').first.to_html

    [features_path, terminal_path, support_path, once_path].each do |path|
      get path
      assert_response :success
      assert_equal landing_header, css_select('header.landing-header').first.to_html
    end
  end

  test 'all landing pages share the footer and its links' do
    [landing_path, features_path, terminal_path, support_path, once_path, faqs_path].each do |path|
      get path

      assert_response :success
      assert_select 'body > footer', count: 1
      assert_select 'body > footer > p', text: 'Don’t forget to have fun!'
      assert_select 'body > footer > nav[aria-label="Footer"] a', count: 4
      assert_select 'body > footer > nav a[role="button"][data-intent="secondary"][data-size="lg"]', count: 4
      assert_select 'body > footer a[href=?]', support_path, text: 'Support'
      assert_select 'body > footer a[href=?]', once_path, text: 'ONCE' do
        assert_select '.icon-wrap .icon[aria-hidden="true"]', count: 1
      end
      assert_select 'body > footer a[href=?]', 'https://github.com/spacepolice10/digibujo', text: 'GitHub' do
        assert_select '.icon', count: 1
      end
      assert_select 'body > footer a[href=?]', faqs_path, text: 'FAQs'
    end
  end

  test 'faqs placeholder is available without authentication' do
    get faqs_path

    assert_response :success
    assert_select 'main[data-page="faqs"] h1', text: 'FAQs'
    assert_select 'main[data-page="faqs"] .empty-state h2', text: 'Coming soon'
  end
end
