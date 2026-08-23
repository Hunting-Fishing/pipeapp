"use strict";

function objectId(value) {
  if (typeof value === "string") return value;
  return String(value && value.id || "");
}

function invoicePaymentsPath(invoiceId) {
  return `/v1/invoice_payments?invoice=${encodeURIComponent(String(invoiceId || ""))}&status=paid&limit=100`;
}

function invoicePaymentIntentId(invoicePayment) {
  const payment = invoicePayment && invoicePayment.payment;
  if (!payment || String(payment.type || "") !== "payment_intent") return "";
  return objectId(payment.payment_intent);
}

function paidInvoicePayments(payload, invoiceId) {
  const expectedInvoiceId = String(invoiceId || "");
  const data = Array.isArray(payload && payload.data) ? payload.data : [];
  return data.filter((entry) => {
    return entry &&
      String(entry.status || "") === "paid" &&
      objectId(entry.invoice) === expectedInvoiceId;
  });
}

module.exports = {
  invoicePaymentIntentId,
  invoicePaymentsPath,
  objectId,
  paidInvoicePayments,
};
