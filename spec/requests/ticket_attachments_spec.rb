require "rails_helper"

RSpec.describe "Ticket attachments", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:other)    { create(:user, :customer) }
  let(:agent)    { create(:user, :agent) }
  let(:ticket)   { create(:ticket, customer: customer) }
  let(:attachment) do
    ticket.attachments.attach(io: StringIO.new("private,contents"), filename: "private.csv", content_type: "text/csv")
    ticket.attachments.first
  end

  it "requires a login" do
    get ticket_attachment_path(ticket, attachment)
    expect(response).to redirect_to(new_user_session_path)
  end

  it "serves the file to the ticket's customer" do
    sign_in customer
    get ticket_attachment_path(ticket, attachment)
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("private,contents")
  end

  it "serves the file to staff" do
    sign_in agent
    get ticket_attachment_path(ticket, attachment)
    expect(response.body).to eq("private,contents")
  end

  it "refuses another customer" do
    sign_in other
    get ticket_attachment_path(ticket, attachment)
    expect(response).to redirect_to(root_path)
  end

  it "does not serve another ticket's attachment through this ticket" do
    other_ticket = create(:ticket, customer: customer)
    sign_in customer
    get ticket_attachment_path(other_ticket, attachment)
    expect(response).to have_http_status(:not_found)
  end

  it "is linked from the staff ticket page through the protected route" do
    attachment
    sign_in agent
    get ticket_path(ticket)
    expect(response.body).to include(ticket_attachment_path(ticket, attachment))
    expect(response.body).not_to include("/rails/active_storage/")
  end

  it "no longer exposes Active Storage's public blob routes" do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:rails_blob_path)
    get "/rails/active_storage/blobs/redirect/#{attachment.blob.signed_id}/private.csv"
    expect(response).to have_http_status(:not_found)
  end
end
