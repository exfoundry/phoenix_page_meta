defmodule TestApp.PageMeta do
  @moduledoc false
  use PhoenixPageMeta, base_url: "https://example.test"

  @enforce_keys [:title, :path]
  defstruct [
    :title,
    :path,
    :breadcrumb_title,
    :parent,
    :description,
    :og_image,
    :og_image_alt,
    :json_ld,
    :canonical_path,
    :icon,
    :skip_breadcrumb,
    :site_name,
    :twitter_site,
    :locale,
    og_type: "website",
    noindex: false,
    supported_locales: nil
  ]
end
