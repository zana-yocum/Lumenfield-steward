/**
 * The timeline's text, one custom label each (Steward_Timeline_*), so wording can change without
 * code and the timeline can be translated. Placeholders such as {0} are filled in with format()
 * from c/portalShared.
 */
import amount from "@salesforce/label/c.Steward_Timeline_Amount";
import amountDue from "@salesforce/label/c.Steward_Timeline_Amount_Due";
import amountPaid from "@salesforce/label/c.Steward_Timeline_Amount_Paid";
import amountPromised from "@salesforce/label/c.Steward_Timeline_Amount_Promised";
import balance from "@salesforce/label/c.Steward_Timeline_Balance";
import connectionProblem from "@salesforce/label/c.Steward_Timeline_Connection_Problem";
import due from "@salesforce/label/c.Steward_Timeline_Due";
import empty from "@salesforce/label/c.Steward_Timeline_Empty";
import emptyFiltered from "@salesforce/label/c.Steward_Timeline_Empty_Filtered";
import eventCommitment from "@salesforce/label/c.Steward_Timeline_Event_Commitment";
import eventCredit from "@salesforce/label/c.Steward_Timeline_Event_Credit";
import eventDispute from "@salesforce/label/c.Steward_Timeline_Event_Dispute";
import eventPayment from "@salesforce/label/c.Steward_Timeline_Event_Payment";
import eventPromise from "@salesforce/label/c.Steward_Timeline_Event_Promise";
import eventStatement from "@salesforce/label/c.Steward_Timeline_Event_Statement";
import failed from "@salesforce/label/c.Steward_Timeline_Failed";
import failedWithReference from "@salesforce/label/c.Steward_Timeline_Failed_With_Reference";
import filterLegend from "@salesforce/label/c.Steward_Timeline_Filter_Legend";
import kindCommitment from "@salesforce/label/c.Steward_Timeline_Kind_Commitment";
import kindCredit from "@salesforce/label/c.Steward_Timeline_Kind_Credit";
import kindDispute from "@salesforce/label/c.Steward_Timeline_Kind_Dispute";
import kindPayment from "@salesforce/label/c.Steward_Timeline_Kind_Payment";
import kindPromise from "@salesforce/label/c.Steward_Timeline_Kind_Promise";
import kindStatement from "@salesforce/label/c.Steward_Timeline_Kind_Statement";
import loading from "@salesforce/label/c.Steward_Timeline_Loading";
import loadingMore from "@salesforce/label/c.Steward_Timeline_Loading_More";
import noAccess from "@salesforce/label/c.Steward_Timeline_No_Access";
import noneSelected from "@salesforce/label/c.Steward_Timeline_None_Selected";
import notAHousehold from "@salesforce/label/c.Steward_Timeline_Not_A_Household";
import notAvailable from "@salesforce/label/c.Steward_Timeline_Not_Available";
import reason from "@salesforce/label/c.Steward_Timeline_Reason";
import showMore from "@salesforce/label/c.Steward_Timeline_Show_More";
import showing from "@salesforce/label/c.Steward_Timeline_Showing";
import showingAll from "@salesforce/label/c.Steward_Timeline_Showing_All";
import status from "@salesforce/label/c.Steward_Timeline_Status";
import title from "@salesforce/label/c.Steward_Timeline_Title";
import type from "@salesforce/label/c.Steward_Timeline_Type";
import undated from "@salesforce/label/c.Steward_Timeline_Undated";
import value from "@salesforce/label/c.Steward_Timeline_Value";

export const LABELS = {
  amount,
  amountDue,
  amountPaid,
  amountPromised,
  balance,
  connectionProblem,
  due,
  empty,
  emptyFiltered,
  eventCommitment,
  eventCredit,
  eventDispute,
  eventPayment,
  eventPromise,
  eventStatement,
  failed,
  failedWithReference,
  filterLegend,
  kindCommitment,
  kindCredit,
  kindDispute,
  kindPayment,
  kindPromise,
  kindStatement,
  loading,
  loadingMore,
  noAccess,
  noneSelected,
  notAHousehold,
  notAvailable,
  reason,
  showMore,
  showing,
  showingAll,
  status,
  title,
  type,
  undated,
  value
};
