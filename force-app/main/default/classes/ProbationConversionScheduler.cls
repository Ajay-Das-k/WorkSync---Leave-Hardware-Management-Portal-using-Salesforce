public class ProbationConversionScheduler implements Schedulable {
    public void execute(SchedulableContext SC) {
        ProbationConversionBatch batch = new ProbationConversionBatch();
        Database.executeBatch(batch);
    }

    public static String scheduleJob() {
        // Schedule to run daily at 1 AM
        return System.schedule('Probation Conversion Job', '0 0 1 * * ?', new ProbationConversionScheduler());
    }
}