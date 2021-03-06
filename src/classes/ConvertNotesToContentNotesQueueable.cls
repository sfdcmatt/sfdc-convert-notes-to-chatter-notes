/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed to be invoked within a trigger or some other scenario where you
 * need exactly one batch of records (up to 200 records) to be converted to ContentNotes.
 *
 * Actual conversion for the execution is delegated to ConvertNotesToContentNotesService.
 */
public with sharing class ConvertNotesToContentNotesQueueable implements Queueable {

    @TestVisible
    private List<ConvertNotesToContentNotesService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------------------

    private ConvertNotesToContentNotesOptions options { get; set; }

    private Set<ID> noteIds { get; set; }

    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds ) {
        this( noteIds, new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds, ConvertNotesToContentNotesOptions options ) {
        this.noteIds = noteIds;
        this.options = options;
    }

    // ----------------------------------------------------------------------

    public void execute( QueueableContext context ) {

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( '[ConvertNotesToContentNotesQueueable.execute] Executing: ' + context );

            List<Note> notes = new List<Note>([
                SELECT
                    id, parentId, ownerId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                WHERE
                    id IN :this.noteIds
                ORDER BY
                    parentId
            ]);

            ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( this.options );

            List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( notes );

            if ( Test.isRunningTest() ) {

                if ( this.mockException != null ) {
                    throw this.mockException;
                }

                if ( this.mockResults != null ) {
                    results = mockResults;
                }

            }

            ConvertNotesToContentNotesLogger.log( context.getJobId(), results );

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertNotesToContentNotesLogger.log( context.getJobId(), e );

        } finally {

            ConvertNotesToContentNotesLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

        }

    }

}