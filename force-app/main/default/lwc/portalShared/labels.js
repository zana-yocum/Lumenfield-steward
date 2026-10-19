/**
 * The portal's customer-facing text, one custom label each (Steward_Portal_*), so wording can
 * change without code and the portal can be translated (ST-18). Placeholders such as {0} are
 * filled in with format().
 */
import connectionProblem from "@salesforce/label/c.Steward_Portal_Connection_Problem";
import notACustomer from "@salesforce/label/c.Steward_Portal_Not_A_Customer";
import tryAgain from "@salesforce/label/c.Steward_Portal_Try_Again";
import failedWithReference from "@salesforce/label/c.Steward_Portal_Failed_With_Reference";
import failedNoReference from "@salesforce/label/c.Steward_Portal_Failed_No_Reference";
import noAccount from "@salesforce/label/c.Steward_Portal_No_Account";
import status from "@salesforce/label/c.Steward_Portal_Status";
import statement from "@salesforce/label/c.Steward_Portal_Statement";
import statementNumbered from "@salesforce/label/c.Steward_Portal_Statement_Numbered";
import dispute from "@salesforce/label/c.Steward_Portal_Dispute";
import disputeNumbered from "@salesforce/label/c.Steward_Portal_Dispute_Numbered";
import disputeLink from "@salesforce/label/c.Steward_Portal_Dispute_Link";
import openADispute from "@salesforce/label/c.Steward_Portal_Open_A_Dispute";
import brand from "@salesforce/label/c.Steward_Portal_Brand";
import navLabel from "@salesforce/label/c.Steward_Portal_Nav_Label";
import myAccount from "@salesforce/label/c.Steward_Portal_My_Account";
import statements from "@salesforce/label/c.Steward_Portal_Statements";
import whatWePromised from "@salesforce/label/c.Steward_Portal_What_We_Promised";
import disputes from "@salesforce/label/c.Steward_Portal_Disputes";
import logOut from "@salesforce/label/c.Steward_Portal_Log_Out";
import accountLoading from "@salesforce/label/c.Steward_Portal_Account_Loading";
import currentBalance from "@salesforce/label/c.Steward_Portal_Current_Balance";
import pastDue from "@salesforce/label/c.Steward_Portal_Past_Due";
import oldestUnpaid from "@salesforce/label/c.Steward_Portal_Oldest_Unpaid";
import none from "@salesforce/label/c.Steward_Portal_None";
import nextPaymentDue from "@salesforce/label/c.Steward_Portal_Next_Payment_Due";
import amountOnDate from "@salesforce/label/c.Steward_Portal_Amount_On_Date";
import nothingDue from "@salesforce/label/c.Steward_Portal_Nothing_Due";
import arrangementTitle from "@salesforce/label/c.Steward_Portal_Arrangement_Title";
import arrangementText from "@salesforce/label/c.Steward_Portal_Arrangement_Text";
import seeStatements from "@salesforce/label/c.Steward_Portal_See_Statements";
import statementsLoading from "@salesforce/label/c.Steward_Portal_Statements_Loading";
import statementsLead from "@salesforce/label/c.Steward_Portal_Statements_Lead";
import noStatements from "@salesforce/label/c.Steward_Portal_No_Statements";
import inDispute from "@salesforce/label/c.Steward_Portal_In_Dispute";
import statementDate from "@salesforce/label/c.Steward_Portal_Statement_Date";
import dueDate from "@salesforce/label/c.Steward_Portal_Due_Date";
import amountDue from "@salesforce/label/c.Steward_Portal_Amount_Due";
import paid from "@salesforce/label/c.Steward_Portal_Paid";
import creditsApplied from "@salesforce/label/c.Steward_Portal_Credits_Applied";
import balance from "@salesforce/label/c.Steward_Portal_Balance";
import payments from "@salesforce/label/c.Steward_Portal_Payments";
import noPayments from "@salesforce/label/c.Steward_Portal_No_Payments";
import statementLoading from "@salesforce/label/c.Steward_Portal_Statement_Loading";
import statementNotYours from "@salesforce/label/c.Steward_Portal_Statement_Not_Yours";
import backToStatements from "@salesforce/label/c.Steward_Portal_Back_To_Statements";
import promisesLead from "@salesforce/label/c.Steward_Portal_Promises_Lead";
import promisesLoading from "@salesforce/label/c.Steward_Portal_Promises_Loading";
import value from "@salesforce/label/c.Steward_Portal_Value";
import monthsCovered from "@salesforce/label/c.Steward_Portal_Months_Covered";
import notApplicable from "@salesforce/label/c.Steward_Portal_Not_Applicable";
import asRecorded from "@salesforce/label/c.Steward_Portal_As_Recorded";
import promisesWrong from "@salesforce/label/c.Steward_Portal_Promises_Wrong";
import noPromises from "@salesforce/label/c.Steward_Portal_No_Promises";
import noPromisesHelp from "@salesforce/label/c.Steward_Portal_No_Promises_Help";
import disputesLead from "@salesforce/label/c.Steward_Portal_Disputes_Lead";
import yourDisputes from "@salesforce/label/c.Steward_Portal_Your_Disputes";
import disputesLoading from "@salesforce/label/c.Steward_Portal_Disputes_Loading";
import reason from "@salesforce/label/c.Steward_Portal_Reason";
import opened from "@salesforce/label/c.Steward_Portal_Opened";
import noDisputes from "@salesforce/label/c.Steward_Portal_No_Disputes";
import formLoading from "@salesforce/label/c.Steward_Portal_Form_Loading";
import whichStatement from "@salesforce/label/c.Steward_Portal_Which_Statement";
import statementOption from "@salesforce/label/c.Steward_Portal_Statement_Option";
import whatsWrong from "@salesforce/label/c.Steward_Portal_Whats_Wrong";
import chooseReason from "@salesforce/label/c.Steward_Portal_Choose_Reason";
import whatYoullNeed from "@salesforce/label/c.Steward_Portal_What_Youll_Need";
import evidenceRequired from "@salesforce/label/c.Steward_Portal_Evidence_Required";
import evidenceOptional from "@salesforce/label/c.Steward_Portal_Evidence_Optional";
import anythingElse from "@salesforce/label/c.Steward_Portal_Anything_Else";
import noCardNumbers from "@salesforce/label/c.Steward_Portal_No_Card_Numbers";
import openTheDispute from "@salesforce/label/c.Steward_Portal_Open_The_Dispute";
import noOpenChoices from "@salesforce/label/c.Steward_Portal_No_Open_Choices";
import alreadyInDispute from "@salesforce/label/c.Steward_Portal_Already_In_Dispute";
import openedHeading from "@salesforce/label/c.Steward_Portal_Opened_Heading";
import openedText from "@salesforce/label/c.Steward_Portal_Opened_Text";
import existingHeading from "@salesforce/label/c.Steward_Portal_Existing_Heading";
import existingText from "@salesforce/label/c.Steward_Portal_Existing_Text";
import couldNotOpen from "@salesforce/label/c.Steward_Portal_Could_Not_Open";
import goToDispute from "@salesforce/label/c.Steward_Portal_Go_To_Dispute";
import openAnother from "@salesforce/label/c.Steward_Portal_Open_Another";
import declinedNotFound from "@salesforce/label/c.Steward_Portal_Declined_Not_Found";
import declinedStatementRequired from "@salesforce/label/c.Steward_Portal_Declined_Statement_Required";
import declinedInvalidReason from "@salesforce/label/c.Steward_Portal_Declined_Invalid_Reason";
import disputeLoading from "@salesforce/label/c.Steward_Portal_Dispute_Loading";
import disputeNotYours from "@salesforce/label/c.Steward_Portal_Dispute_Not_Yours";
import whatToSend from "@salesforce/label/c.Steward_Portal_What_To_Send";
import required from "@salesforce/label/c.Steward_Portal_Required";
import optional from "@salesforce/label/c.Steward_Portal_Optional";
import uploadHeading from "@salesforce/label/c.Steward_Portal_Upload_Heading";
import uploadLead from "@salesforce/label/c.Steward_Portal_Upload_Lead";
import addFiles from "@salesforce/label/c.Steward_Portal_Add_Files";
import uploadThanksOne from "@salesforce/label/c.Steward_Portal_Upload_Thanks_One";
import uploadThanksMany from "@salesforce/label/c.Steward_Portal_Upload_Thanks_Many";
import disputeClosed from "@salesforce/label/c.Steward_Portal_Dispute_Closed";
import backToDisputes from "@salesforce/label/c.Steward_Portal_Back_To_Disputes";

export const LABELS = {
  connectionProblem,
  notACustomer,
  tryAgain,
  failedWithReference,
  failedNoReference,
  noAccount,
  status,
  statement,
  statementNumbered,
  dispute,
  disputeNumbered,
  disputeLink,
  openADispute,
  brand,
  navLabel,
  myAccount,
  statements,
  whatWePromised,
  disputes,
  logOut,
  accountLoading,
  currentBalance,
  pastDue,
  oldestUnpaid,
  none,
  nextPaymentDue,
  amountOnDate,
  nothingDue,
  arrangementTitle,
  arrangementText,
  seeStatements,
  statementsLoading,
  statementsLead,
  noStatements,
  inDispute,
  statementDate,
  dueDate,
  amountDue,
  paid,
  creditsApplied,
  balance,
  payments,
  noPayments,
  statementLoading,
  statementNotYours,
  backToStatements,
  promisesLead,
  promisesLoading,
  value,
  monthsCovered,
  notApplicable,
  asRecorded,
  promisesWrong,
  noPromises,
  noPromisesHelp,
  disputesLead,
  yourDisputes,
  disputesLoading,
  reason,
  opened,
  noDisputes,
  formLoading,
  whichStatement,
  statementOption,
  whatsWrong,
  chooseReason,
  whatYoullNeed,
  evidenceRequired,
  evidenceOptional,
  anythingElse,
  noCardNumbers,
  openTheDispute,
  noOpenChoices,
  alreadyInDispute,
  openedHeading,
  openedText,
  existingHeading,
  existingText,
  couldNotOpen,
  goToDispute,
  openAnother,
  declinedNotFound,
  declinedStatementRequired,
  declinedInvalidReason,
  disputeLoading,
  disputeNotYours,
  whatToSend,
  required,
  optional,
  uploadHeading,
  uploadLead,
  addFiles,
  uploadThanksOne,
  uploadThanksMany,
  disputeClosed,
  backToDisputes
};
