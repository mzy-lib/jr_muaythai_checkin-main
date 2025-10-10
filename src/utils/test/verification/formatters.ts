import { Member } from '../../../types/database';

/**
 * Formats member data for console output
 */
export function formatMemberInfo(member: Member): string {
  return [
    `- ${member.name} (${member.email || 'no email'})`,
    `  Membership: ${member.membership || 'none'}`,
    `  Status: ${member.is_new_member ? 'New' : 'Regular'}`,
    member.membership_expiry ? 
      `  Expires: ${new Date(member.membership_expiry).toLocaleDateString()}` : '',
    member.remaining_classes ? 
      `  Classes: ${member.remaining_classes}` : ''
  ].filter(Boolean).join('\n');
}

/**
 * Formats verification results for console output
 */
export function formatVerificationResults(
  members: Member[], 
  checkIns: number
): string {
  return [
    '\nTest Data Verification Results:',
    `Found ${members.length} test members:`,
    ...members.map(m => formatMemberInfo(m)),
    `\nTotal check-ins: ${checkIns}`,
    '✓ Verification complete'
  ].join('\n');
}