# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::CreateService, type: :service do
  subject(:invoice_service) do
    described_class.new(subscription: subscription, timestamp: timestamp.to_i)
  end

  describe 'create' do
    let(:subscription) do
      create(
        :subscription,
        plan: plan,
        anniversary_date: (Time.zone.now - 2.years).to_date,
        started_at: Time.zone.now - 2.years,
      )
    end

    let(:billable_metric) { create(:billable_metric, aggregation_type: 'count_agg') }

    before do
      create(:one_time_charge, plan: subscription.plan, charge_model: 'standard')
    end

    context 'when billed monthly on beginning of period' do
      let(:timestamp) { Time.zone.now.beginning_of_month }

      let(:plan) do
        create(:plan, interval: 'monthly', frequency: 'beginning_of_period')
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(timestamp - 1.month)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.issuing_date.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)

          expect(result.invoice.amount_cents).to eq(100)
          expect(result.invoice.amount_currency).to eq('EUR')
          expect(result.invoice.vat_amount_cents).to eq(20)
          expect(result.invoice.vat_amount_currency).to eq('EUR')
          expect(result.invoice.total_amount_cents).to eq(120)
          expect(result.invoice.total_amount_currency).to eq('EUR')
        end
      end
    end

    context 'when billed monthly on subscription anniversary' do
      let(:timestamp) { subscription.anniversary_date.beginning_of_day + 2.years }
      let(:plan) do
        create(:plan, interval: 'monthly', frequency: 'subscription_date')
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(timestamp - 1.month)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)
        end
      end
    end

    context 'when billed monthly on first month' do
      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:started_at) { timestamp - 3.days }

      let(:subscription) do
        create(
          :subscription,
          plan: plan,
          anniversary_date: started_at.to_date,
          started_at: started_at,
        )
      end

      let(:plan) do
        create(:plan, interval: 'monthly', frequency: 'beginning_of_period')
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(subscription.anniversary_date)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)
        end
      end
    end

    context 'when billed yearly on beginning of period' do
      let(:timestamp) { Time.zone.now.beginning_of_month }

      let(:plan) do
        create(:plan, interval: 'yearly', frequency: 'beginning_of_period')
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(timestamp - 1.year)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)
        end
      end
    end

    context 'when billed yearly on subscription anniversary' do
      let(:timestamp) { subscription.anniversary_date.beginning_of_day + 2.years }

      let(:plan) do
        create(:plan, interval: 'yearly', frequency: 'subscription_date')
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(timestamp - 1.year)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)
        end
      end
    end

    context 'when billed yearly on first year' do
      let(:plan) do
        create(:plan, interval: 'yearly', frequency: 'beginning_of_period')
      end

      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:started_at) { Time.zone.today - 3.months }
      let(:subscription) do
        create(
          :subscription,
          plan: plan,
          anniversary_date: started_at.to_date,
          started_at: started_at,
        )
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.invoice.to_date).to eq(timestamp - 1.day)
          expect(result.invoice.from_date).to eq(subscription.anniversary_date)
          expect(result.invoice.subscription).to eq(subscription)
          expect(result.invoice.fees.subscription_kind.count).to eq(1)
          expect(result.invoice.fees.charge_kind.count).to eq(1)
        end
      end
    end

    context 'when plan is pay in advance' do
      let(:plan) do
        create(:plan, interval: 'yearly', frequency: 'beginning_of_period', pay_in_advance: true)
      end

      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:started_at) { Time.zone.today - 3.months }
      let(:subscription) do
        create(
          :subscription,
          plan: plan,
          anniversary_date: started_at.to_date,
          started_at: started_at,
        )
      end

      it 'creates an invoice' do
        result = invoice_service.create

        aggregate_failures do
          expect(result.invoice.issuing_date).to eq(timestamp.to_date)
        end
      end
    end

    context 'when subscription is terminated and plan is pay in arrear' do
      let(:plan) do
        create(:plan, interval: 'monthly', frequency: 'beginning_of_period', pay_in_advance: false)
      end

      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:started_at) { Time.zone.today - 3.months }
      let(:subscription) do
        create(
          :subscription,
          plan: plan,
          anniversary_date: started_at.to_date,
          started_at: started_at,
          status: :terminated,
        )
      end

      it 'creates an invoice with subscription fee' do
        result = invoice_service.create

        expect(result.invoice.fees.subscription_kind.count).to eq(1)
      end
    end

    context 'when subscription has a pending next subscription' do
      let(:plan) { create(:plan) }
      let(:timestamp) { Time.zone.now.beginning_of_month }

      let(:next_subscription) do
        create(
          :subscription,
          previous_subscription_id: subscription.id,
          status: :pending,
        )
      end

      before { next_subscription }

      it 'enqueues a job to terminate the subscription' do
        expect do
          invoice_service.create
        end.to have_enqueued_job(Subscriptions::TerminateJob)
      end
    end
  end
end