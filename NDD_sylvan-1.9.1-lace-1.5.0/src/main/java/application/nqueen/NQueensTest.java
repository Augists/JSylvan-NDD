package application.nqueen;

import org.ants.jpndd.diagram.NDD;

public class NQueensTest {
    public static final int NDD_TABLE_SIZE = 100000000;

    private static void declareFields(int n) {
        for (int i = 0; i < n; i++) {
            NDD.declareField(n);
        }
    }

    private static void build(int i, int j, int n, NDD[][] impBatch) {
        NDD a, b, c, d;
        a = b = c = d = NDD.getTrue();

        int k, l;

        for (l = 0; l < n; l++) {
            if (l != j) {
                NDD mp = NDD.ref(NDD.imp(NDD.getVar(i, j), NDD.getNotVar(i, l)));
                a = NDD.andTo(a, mp);
                NDD.deref(mp);
            }
        }

        for (k = 0; k < n; k++) {
            if (k != i) {
                NDD mp = NDD.ref(NDD.imp(NDD.getVar(i, j), NDD.getNotVar(k, j)));
                b = NDD.andTo(b, mp);
                NDD.deref(mp);
            }
        }

        for (k = 0; k < n; k++) {
            int ll = k - i + j;
            if (ll >= 0 && ll < n) {
                if (k != i) {
                    NDD mp = NDD.ref(NDD.imp(NDD.getVar(i, j), NDD.getNotVar(k, ll)));
                    c = NDD.andTo(c, mp);
                    NDD.deref(mp);
                }
            }
        }

        for (k = 0; k < n; k++) {
            int ll = i + j - k;
            if (ll >= 0 && ll < n) {
                if (k != i) {
                    NDD mp = NDD.ref(NDD.imp(NDD.getVar(i, j), NDD.getNotVar(k, ll)));
                    d = NDD.andTo(d, mp);
                    NDD.deref(mp);
                }
            }
        }

        c = NDD.andTo(c, d);
        b = NDD.andTo(b, c);
        a = NDD.andTo(a, b);
        NDD.deref(d);
        impBatch[i][j] = a;
    }

    public static void main(String[] args) {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 8;
        
        long maxMemory = 8L * 1024 * 1024 * 1024;
        NDD.initNDD(NDD_TABLE_SIZE, 1 + Math.max(1000, (int) (Math.pow(4.4, n - 6)) * 1000), 10000, maxMemory);

        double startTime = System.currentTimeMillis();

        declareFields(n);

        NDD[] orBatch = new NDD[n];
        NDD[][] impBatch = new NDD[n][n];

        for (int i = 0; i < n; i++) {
            NDD condition = NDD.getFalse();
            for (int j = 0; j < n; j++) {
                condition = NDD.orTo(condition, NDD.getVar(i, j));
            }
            orBatch[i] = condition;
        }

        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                build(i, j, n, impBatch);
            }
        }

        NDD queen = NDD.getTrue();

        for (int i = 0; i < n; i++) {
            queen = NDD.andTo(queen, orBatch[i]);
            NDD.deref(orBatch[i]);
        }
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                queen = NDD.andTo(queen, impBatch[i][j]);
                NDD.deref(impBatch[i][j]);
            }
        }
        double endTime = System.currentTimeMillis();
        
        System.out.println("N=" + n + ", solutions=" + NDD.satCount(queen) + ", time=" + ((endTime - startTime) / 1000) + "s");
        System.out.println("NDD nodes: " + NDD.nodeCount());
    }
}
