class Admin::DropdownOptionsController < ApplicationController
  before_action :require_admin!
  before_action :set_dropdown_option, only: [:update, :toggle_active]

  TABS = {
    "ticket_forms"       => DropdownOption::TICKET_FORM_CATEGORIES,
    "hiring_termination" => DropdownOption::HIRING_TERMINATION_CATEGORIES
  }.freeze

  def index
    load_index_collections
    @new_dropdown_option = DropdownOption.new(category: @active_category)
  end

  def create
    @dropdown_option = DropdownOption.new(dropdown_option_params)
    if @dropdown_option.save
      redirect_to admin_dropdown_options_path(tab: tab_for(@dropdown_option.category), category: @dropdown_option.category),
        notice: "Option added successfully."
    else
      load_index_collections(category: @dropdown_option.category)
      @new_dropdown_option = @dropdown_option
      @reopen_modal = "newDropdownOptionModal"
      flash.now[:alert] = @dropdown_option.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @dropdown_option.update(update_params)
      redirect_to admin_dropdown_options_path(tab: tab_for(@dropdown_option.category), category: @dropdown_option.category),
        notice: "Option updated successfully."
    else
      load_index_collections(category: @dropdown_option.category)
      @options = [@dropdown_option] + @options.reject { |o| o.id == @dropdown_option.id }
      @new_dropdown_option = DropdownOption.new(category: @active_category)
      @reopen_modal = view_context.dom_id(@dropdown_option, :edit)
      flash.now[:alert] = @dropdown_option.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def toggle_active
    @dropdown_option.update!(is_active: !@dropdown_option.is_active)
    status = @dropdown_option.is_active? ? "enabled" : "disabled"
    redirect_back fallback_location: admin_dropdown_options_path,
      notice: "\"#{@dropdown_option.label}\" has been #{status}."
  end

  private

  def load_index_collections(category: nil)
    preferred_tab = category ? tab_for(category) : params[:tab]
    @active_tab      = TABS.key?(preferred_tab) ? preferred_tab : "ticket_forms"
    @tab_categories  = TABS[@active_tab]
    @active_category = category || (@tab_categories.include?(params[:category]) ? params[:category] : @tab_categories.first)

    options = DropdownOption.where(category: @active_category).ordered
    if params[:search].present?
      term    = "%#{params[:search].strip}%"
      options = options.where("label ILIKE :term OR value ILIKE :term", term: term)
    end
    @options = options.page(params[:page]).per(9)
  end

  def set_dropdown_option
    @dropdown_option = DropdownOption.find(params[:id])
  end

  def tab_for(category)
    DropdownOption::TICKET_FORM_CATEGORIES.include?(category) ? "ticket_forms" : "hiring_termination"
  end

  def dropdown_option_params
    params.require(:dropdown_option).permit(:category, :label, :value, :position)
  end

  # category is locked once created; ignore any submitted value and keep the existing one
  def update_params
    dropdown_option_params.except(:category)
  end
end
