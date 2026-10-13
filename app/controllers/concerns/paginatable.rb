module Paginatable
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)

    records = scope.limit(per_page).offset((page - 1) * per_page)
    [ records, { page: page, per_page: per_page, total_count: scope.count } ]
  end
end
