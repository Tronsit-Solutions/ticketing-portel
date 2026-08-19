module ApplicationHelper
  def display_audit_value(value)
    case value
    when nil then "—"
    when true then "Yes"
    when false then "No"
    when Hash, Array then value.presence ? value.to_json : "—"
    else value.to_s.presence || "—"
    end
  end

  def sortable_column_link(path, label, key, current_sort:, current_direction:, sort_param: :sort, direction_param: :direction, extra_params: {})
    direction = (current_sort == key && current_direction == "asc") ? "desc" : "asc"
    url = send(path, extra_params.merge(sort_param => key, direction_param => direction))

    link_to url, class: "text-dark text-decoration-none" do
      icon_class = if current_sort == key
        current_direction == "asc" ? "bi-arrow-up" : "bi-arrow-down"
      else
        "bi-arrow-down-up text-muted"
      end
      safe_join([label, content_tag(:i, "", class: "bi #{icon_class}", style: current_sort == key ? nil : "font-size:11px;")])
    end
  end
end
