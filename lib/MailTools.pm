package MailTools;

=chapter NAME
MailTools - bundle of ancient email modules

=chapter SYNOPSIS

 # This is a place-holder for the distribution

=chapter DESCRIPTION

MailTools is a bundle: an ancient form of combining packages into one
distribution.  Gladly, it can be distributed as if it is a normal
distribution as well.

B<Be warned:> The code you find here is very old.  It works for simple
emails, but when you start with new code then please use more
sofisticated libraries.  The main reason that you still find this code
on CPAN, is because many books use it as example.

=section Component

In this distribution, you find

=over 4

=item Mail::Address
Parse email address from a header line.

=item Mail::Cap
Interpret mailcap files: mappings of file-types to applications as used
by many command-line email programs.

=item Mail::Field
Simplifies access to (some) email header fields.  Used by M<Mail::Header>.

=item Mail::Filter
Process M<Mail::Internet> messages.

=item Mail::Header
Collection of M<Mail::Field> objects, representing the header of a
M<Mail::Internet> object.

=item Mail::Internet
Represents a single email message, with header and body.

=item Mail::Mailer
Send M<Mail::Internet> emails via direct smtp or local MTA's.

=item Mail::Send
Build a M<Mail::Internet> object, and then send it out using
M<Mail::Mailer>.

=item Mail::Util
"Smart functions" you should not depend on.

=back

=cut

1;
