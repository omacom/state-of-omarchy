module ApplicationHelper
  SITE_DESCRIPTION = "The yearly survey about Omarchy Linux. #StateOfOmarchy".freeze

  # Shared head tags, rendered once per page with that page's title.
  def seo_tags(title, description: SITE_DESCRIPTION, image: "/og-image.png")
    content_for(:title, title)
    image_url = image.start_with?("http") ? image : "#{request.base_url}#{image}"
    safe_join([
      tag.meta(name: "description", content: description),
      tag.meta(property: "og:type", content: "website"),
      tag.meta(property: "og:site_name", content: "State of Omarchy"),
      tag.meta(property: "og:title", content: title),
      tag.meta(property: "og:description", content: description),
      tag.meta(property: "og:image", content: image_url),
      tag.meta(name: "twitter:card", content: "summary_large_image"),
      tag.meta(name: "twitter:title", content: title),
      tag.meta(name: "twitter:description", content: description),
      tag.meta(name: "twitter:image", content: image_url)
    ], "\n")
  end

  def site_title
    "#{current_survey.title} #{current_survey.year}"
  end

  # Tailwind class merging is intentionally simple: later classes win by CSS order, so
  # callers pass overrides that don't conflict with the base.
  def cn(*classes)
    classes.flatten.compact_blank.join(" ")
  end
end
