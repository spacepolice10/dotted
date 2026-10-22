module IconHelper
  def icon(name, options = {})
    icon_name = name.presence || Iconable::DEFAULT_ICON
    content_tag(
      :span,
      content_tag(:i, '', class: 'icon', style: "--icon-mask: var(--icon-#{icon_name});",
                          aria: { hidden: true }),
      **options,
      class: class_names('icon-wrap', options[:class]),
      style: options[:style]
    ).html_safe
  end
end
