# frozen_string_literal: true

# Prefer routes, frame ids, aria labels, headings, and visible copy over CSS classes.
# Classes are styling hooks and will keep changing during UI refactors.
module DomAssertions
  def assert_page_text(text)
    assert_match text, response.body
  end

  def assert_no_page_text(text)
    assert_no_match text, response.body
  end

  def assert_link(path, aria_label: nil, text: nil, count: nil, minimum: nil, maximum: nil, &block)
    selector = "a[href=\"#{path}\"]"
    selector += "[aria-label=\"#{aria_label}\"]" if aria_label

    options = {}
    options[:text] = text if text
    options[:count] = count unless count.nil?
    options[:minimum] = minimum unless minimum.nil?
    options[:maximum] = maximum unless maximum.nil?

    if block
      assert_select selector, options, &block
    else
      assert_select selector, **options
    end
  end

  def assert_turbo_frame(id, src: nil, count: nil, minimum: nil, &block)
    selector = "turbo-frame##{id}"
    selector += "[src=\"#{src}\"]" if src

    options = {}
    options[:count] = count unless count.nil?
    options[:minimum] = minimum unless minimum.nil?

    if block
      assert_select selector, options, &block
    else
      assert_select selector, **options
    end
  end

  def assert_form_action(path, **options, &block)
    if block
      assert_select "form[action=?]", path, options, &block
    else
      assert_select "form[action=?]", path, **options
    end
  end

  def assert_heading(text, level: nil, **options)
    tag = level ? "h#{level}" : "h1, h2, h3, h4, h5, h6"
    assert_select tag, text: text, **options
  end

  def assert_nav_link(path, label:, count: nil)
    options = count.nil? ? {} : { count: count }
    assert_select "nav a[href=?][aria-label=?]", path, label, **options
  end

  def assert_tabbar_link(path, label:, active: false)
    if active
      assert_select "nav.tabbar--navigation span.tabbar--item-active[aria-label=?][aria-current=page]", label
      assert_select "nav.tabbar--navigation a[href=?]", path, count: 0
    else
      assert_select "nav.tabbar--navigation a.tabbar--item[href=?][aria-label=?]", path, label
    end
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include DomAssertions
end
