/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for mass converting all notes in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertNotesToContentNotesService.
 */
public with sharing class ConvertNotesToContentNotesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private List<ConvertNotesToContentNotesService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------

    @TestVisible
    private ConvertNotesToContentNotesOptions options { get; set; }

    public ConvertNotesToContentNotesBatchable() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesBatchable( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
    }

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.start] Starting: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.start] Options: ' + this.options );

        if ( this.options == null || this.options.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                WHERE
                    parentId IN :this.options.parentIds
                ORDER BY
                    parentId
            ]);

        }

    }

    public void execute( Database.BatchableContext context, List<Note> notes ) {

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( '[ConvertNotesToContentNotesBatchable.execute] Executing: ' + context );
            System.debug( '[ConvertNotesToContentNotesBatchable.execute] Options: ' + this.options );

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

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Options: ' + this.options );

        ConvertNotesToContentNotesLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

    }

}