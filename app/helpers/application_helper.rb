# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end

  def bullet_marker_colour(bullet)
    return if bullet.done?

    marker_colour = Colourable.colour_variable_of(bullet.collection&.colour)
    "color: #{marker_colour};" if marker_colour.present?
  end

  def mobile_variant?
    request.variant.include?(:mobile)
  end

  def back_link_to(url = search_path, **options, &block)
    data = (options[:data] || {}).dup
    data[:role] = 'button'
    data[:controller] = [data[:controller], 'navigation'].compact_blank.join(' ')
    data[:action] = [data[:action], 'click->navigation#back'].compact_blank.join(' ')

    link_to(url, options.merge(data: data), &block)
  end

  # A search result row is itself one big link, so anchors inside a rich-text
  # body would nest and break the row. Unwrap them, keeping their text.
  def highlight_search_result(html, query)
    highlighted = Search::Highlight.call(html, query)
    return highlighted unless highlighted.include?('<a')

    fragment = Loofah.html5_fragment(highlighted)
    fragment.css('a').each { |anchor| anchor.replace(anchor.children) }
    fragment.to_html.html_safe
  end

  def search_results_count(size)
    label = size == Search::GlobalRequest::LIMIT ? "#{size}+" : size
    "#{label} #{'result'.pluralize(size)}"
  end

  def time_period(time = Time.now)
    case time.hour
    when 5...12 then 'morning'
    when 12...17 then 'afternoon'
    when 17...21 then 'evening'
    else 'night'
    end
  end
end
