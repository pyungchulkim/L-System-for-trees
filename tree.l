/* An experimental forest with trees for my art study. The trees are
 * with no leaves; I'm only interested in the bones that create rhythms
 * over the sequence of events in nature, i.e., the plant biology and tropism.
 * The trees are developed using the L-system fractal and simulated using
 * CPFG developed by Univ. of Calgary. Although tree growth is heavily relied
 * upon the plant biology, I model trees as how they look at the end of growth
 * rather than growing them biologically. For instance, I do not model tree
 * branches to get thicker as they accumulate nutrients from leaves, but
 * calculate their width according to the Da Vinci's observation.
 *
 * Here are formulae that I'm using in the system:
 *
 * 1. Calculation of the next top/lateral width
 * I use the Da Vinci formula, which states that the influx and outflux
 * are the same amount at any tree branches.
 * Suppose w1, w2, w3i are the width of mother branch, top and i-th lateral
 * branch, respectively. Then, w1^2 = w2^2 + w31^2 + w32^2 + ... + w3n^2.
 * For simplicity, I assume that all lateral branches have the same mean width.
 * I.e., w1^2 = w2^2 + n*w31^2.
 * The leadership of top (w2) is denoted as r = w2/w1.
 * That is, w2 = r*w1, w31 = sqrt((1-r^2)/n) * w1.
 *
 * 2. Calculation of the length of the current internode
 * Thicker branches look longer as the result of pruning.
 * TODO: we probably do not need this tweak if pruning does a good job.
 *
 * 3. Pruning apexes
 * Lateral branches die as they get old due to lack of light or space. 
 * I prun branches more at the initial stage using a power function.
 *
 * 4. Estimate life time of a branch
 * Several calculation is based upon the estimated life of a branch in years.
 * Assuming branching occurs every year, the width at n-th year will be
 * w*r^n, where n needs to be adjusted for the year when no branching occurs.
 *
 * 5. Other notes
 * - All measurements are in foot.
 * - Each iteration of my L-system represents a year.
 * - Deterministic productions (rather than stochastic) are used; 
 *   Hence, the order of the productions in the program are important.
 *
 * by Pyungchul Kim, 2024
 * http://orderedrandom.com
 */

/* Program-wide parameters - hard-coded.
 * Prefixed by 'h' for program readability.
 */
#define	hL_PROD_ARRAY_SIZE	10	/* max # of lateral productions */
#define hT_WID_R_MAX		0.98	/* width reduction rate when no branching */
#define hSTD_R			0.2	/* ratio of std to mean for nran() */
#define hGROUND_D 		200	/* ground depth */
#define hGROUND_W 		300	/* ground width */
#define hBGROUND_H		100	/* background height */
#define hMAX_TREES		1000	/* max # of trees to plant */
#define hBACK_TEXTURE 		1    	/* background texture: 0 for none */
#define hGROUND_TEXTURE 	2    	/* ground texture: 0 for none */

/* Frequently-used nran in the program: 20% as std, always positive */
#define NRAN(m)			fabs(nran(m, (m) * hSTD_R))

/* Program-wide parameters - can be set by 'param' panel.
 * Prefixed by 'p' for program readability.
 */
#define pSEED 0	/* 0 for no seed setting */
#define pMAX_YEARS 40	/* # of iteration - each step for a year */
#define pPLANT_ANGLE 30		/* plant only within this angle for optimization */
#define pFOR_ORSTUDIO 0		/* for ORStudio input: no BG, no texture */

/* Number of trees to plant for each type - can be set by 'planting' panel */
#define pNUM_TREE_0 0
#define pNUM_TREE_1 0
#define pNUM_TREE_2 0
#define pNUM_TREE_3 0
#define pNUM_TREE_4 0
#define pNUM_TREE_5 0
#define pNUM_TREE_6 0
#define pNUM_TREE_7 0
#define pNUM_TREE_8 10
#define pNUM_TREE_9 0
#define pNUM_TREE_10 0
#define pNUM_TREE_11 0
#define hMAX_TREE_TYPES		12	/* max # of pre-packaged tree types */

/* Parameters for each tree species.
 * Prefixed by 't' for program readability.
 * - use 'param' panel to customize these parameters.
 * - later, a defined set of parameters can be packaged into predefined tree types
 */
#define tWID_MIN 0.020833	/* 0.083 = 1/12 foot */
#define tWID_MAX 0.500000	/* lowest trunk width */
#define tPRUN_R 0.910000	/* pruning rate */
#define tLEN_MIN 0.250000	/* min internode length */
#define tLEN_MAX 1.500000	/* max internode length */
#define tL_MAX 3	/* max # of lateral branch. max=L_PROD_ARRAY_SIZE */
#define tT_WID_R 0.700000	/* top width to mother when branching. 1 for all top */ 
#define tT_ANG 18	/* mean for top apex angle. degree of alternation */
#define tL_ANG 50	/* mean for lateral apex angle */
#define tGRAV_SI 0.130000		/* gravity intensity of branch start */
#define tGRAV_MI -0.060000		/* gravity intensity of branch middle */
#define tGRAV_EI -0.030000		/* gravity intensity of branch end */
#define tSTART_DEPTH 0.000000			/* depth of the first branching - no pruning */
#define tTEXTURE 3			/* texture index for bark */

/* Parameter indexes
 * - this has to be consistent with the above tree parameters.
 */
#define	iWID_MIN	0
#define iWID_MAX	1
#define iPRUN_R		2
#define iLEN_MIN	3
#define iLEN_MAX	4
#define iL_MAX		5
#define	iT_WID_R	6
#define iT_ANG		7
#define iL_ANG		8
#define iGRAV_SI	9
#define iGRAV_MI	10
#define iGRAV_EI	11
#define iSTART_DEPTH	12
#define iTEXTURE	13
#define hMAX_IDX	14	/* total # of parameters */

/* Calculating the next top/lateral width */
#define	T_WID(t,w1)	(p[t][iT_WID_R] * (w1))
#define	L_WID(t,w1,n)	(sqrt((1 - p[t][iT_WID_R]^2) / (n)) * (w1))

/* Calculating the length of the current internode */
#define LEN(t,w)	(p[t][iLEN_MIN] + \
			(p[t][iLEN_MAX] - p[t][iLEN_MIN]) * ((w) / p[t][iWID_MAX]))

/* Pruning apexes */
#define	IS_L_ALIVE(t,m,a)	(ran(1) < (1 - p[t][iPRUN_R]) * ((a) / (m))^1.25)

/* Estimate life time of a branch in years */
#define LIFE(t,w)	ceil(log(p[t][iWID_MIN] / (w)) / log(p[t][iT_WID_R]))


lsystem: 1

define: { 
	/* Pre-defined tree types parameters */
	array p[hMAX_TREE_TYPES][hMAX_IDX] = {
	    
	  /* type-0: reserved for custom tree */
	  tWID_MIN, tWID_MAX, tPRUN_R, tLEN_MIN, tLEN_MAX, tL_MAX, tT_WID_R,
	  tT_ANG, tL_ANG, tGRAV_SI, tGRAV_MI, tGRAV_EI, tSTART_DEPTH, tTEXTURE,

	  /* type-1: big maple */
	  0.04, 3, 0.5, 0.5, 2.2, 2, 0.85, 5, 40, -0.05, 0.04, 0.02, 0, 3,

	  /* type-2: birch */
	  0.02, 1.5, 0.48, 0.5, 2.0, 2, 0.90, 10, 60, -0.03, 0.03, 0.17, 0, 3,

	  /* type-3: cedar */
	  0.02, 3.0, 0.7, 0.33, 2.2, 6, 0.95, 0, 100, 0.05, -0.06, -0.02, 0, 3,

	  /* type-4: cherry */
	  0.02, 1.5, 0.5, 0.5, 2.2, 4, 0.77, 10, 50, 0.03, 0.02, -0.08, 0, 3,

	  /* type-5: cottonwood */
	  0.04, 2, 0.27, 0.33, 3, 2, 0.85, 5, 80, -0.1, 0.05, 0.12, 0, 3,

	  /* type-6: oak */
	  0.02, 1.5, 0.04, 0.33, 2.4, 1, 0.8, 25, 70, 0.04, -0.06, 0.08, 0, 3,

	  /* type-7: pine */
	  0.04, 2.0, 0.2, 0.5, 2.4, 6, 0.9, 10, 100, -0.07, 0.03, -0.03, 0, 3,

	  /* type-8: weeping willow */
	  0.02, 1.5, 0.04, 1.0, 1.67, 1, 0.8, 10, 40, -0.09, 0.08, 0.2, 0, 3,

	  /* type-9: rhody */
	  0.02, 1.0, 0.9, 0.25, 1.5, 4, 0.70, 20, 50, 0.13, -0.11, -0.04, -0.1, 3,

	  /* type-10: vine maple */
	  0.015, 0.5, 0.6, 0.25, 2.5, 2, 0.6, 15, 45, -0.15, 0, 0.08, -1.0, 3,

	  /* type-11: fir */
	  0.02, 3.0, 0.62, 0.33, 2.0, 6, 0.92, 1, 65, 0.05, -0.01, 0.04, 0, 3
	};

	/* Placeholder for the number of trees for each type */
	array n_t[hMAX_TREE_TYPES] = {
	  pNUM_TREE_0, pNUM_TREE_1, pNUM_TREE_2, pNUM_TREE_3, pNUM_TREE_4,
	  pNUM_TREE_5, pNUM_TREE_6, pNUM_TREE_7, pNUM_TREE_8, pNUM_TREE_9,
	  pNUM_TREE_10, pNUM_TREE_11
	}; 

	/* Placeholder for trees to plant */
	array trees[hMAX_TREES][3];	/* location (x,z), type */ 

	/* Placeholder for lateral branch info */
	array l_r[hL_PROD_ARRAY_SIZE];	/* rotation */ 
	array l_a[hL_PROD_ARRAY_SIZE]; 	/* angle */
	array l_w[hL_PROD_ARRAY_SIZE]; 	/* width */
	array l_e[hL_PROD_ARRAY_SIZE]; 	/* estimated life time */
}		

start: {
	curr_y = -1; 	/* flag that growth has not started */
	if (pSEED != 0) { srand(pSEED); }	/* set random seed */

	/* Calculate where to plant the trees and put them into the placeholder.
	 * TODO: For now, we do not consider minimum distance between the trees.
	 */
	/* dimension of ground based upon the plant angle */
	d_max = hGROUND_D;
	w_max = hGROUND_D * tan(pPLANT_ANGLE / 2);
	t = 0;
	n = 0;
	while (t < hMAX_TREE_TYPES) {
	  i = 0;
	  while (i < n_t[t]) {
	    w = ran(w_max);
	    d = ran(d_max);
	    while (d < d_max / w_max * w) {
	      /* outside the plant angle; try again */
	      w = ran(w_max);
	      d = ran(d_max);
	    }
	    if (ran(1) < 0.5) {	/* plant the half in the opposite side */
	      w = -w;
	    }
	    /* save the tree info at the placeholder */
	    if (n < hMAX_TREES) {
	      trees[n][0] = w;
	      trees[n][1] = -d;
	      trees[n][2] = t;
	      n = n + 1;
	    }
	    i = i + 1;
	  }
	  t = t + 1;
	}
	if (n == 1) {	/* special case: plant at the vintage point for debugging */
	  trees[0][0] = 0;
	  trees[0][1] = -60;
	}

	total_trees = n;
	printf("Number of trees to plant: %0.f\n", n);
	curr_n = -1;
}

starteach: {
	if (curr_y >=0) {
	  printf("Year: %0.f\n", curr_y); 
	}
}

endeach: {
	if (curr_y == pMAX_YEARS) {
	  stop(1);	/* pause for the 1st tree and continue when 'Run' */
	  curr_n = curr_n + 1;
	  if (curr_n < total_trees) {
	    printf("\nStart to grow tree [%0.f]\n", curr_n);
	    curr_y = 0;	/* restart the year for a new tree growth */
	  } else {
	    printf("\nAll done!\n");
	    curr_y = -1;	/* all growth is done */
	    stop(0);	/* stop the simulation */
	  }
	}
	if (curr_y >=0) {	/* growing: advance to next year */
	  curr_y = curr_y + 1;
	}
}

/* Background and ground plain */
#define BACKGROUND(w,d,h) 	\
	[@Tx(hBACK_TEXTURE);(0)!(0.01)@M(-w/2,0,-(d+10)){f(h)-(90)f(w)-(90)f(h)-(90)f(w)}] \
	[@Tx(hGROUND_TEXTURE);(0)!(0.01)@M(-w/2,0,0){&(90)f(d)-(90)f(w)-(90)f(d)-(90)f(w)}]

/* Planting a new tree (type=t) at location (x,y,z) */
#define PLANT_TREE(x,y,z,n,t,txt)	@M(x,y,z)@Tx(txt)!(p[t][iWID_MAX])[SV(0,0)?H(0,0,0)A(n,0,p[t][iWID_MAX],pMAX_YEARS)E]

derivation length: 1000000

axiom: 	P(total_trees)B

P(n) : (n > 0) {	/* plant all trees */ 
	  n = n - 1; 
	  x = trees[n][0];
	  z = trees[n][1];
	  t = trees[n][2];
	  y = p[t][iSTART_DEPTH];
	  txt = (pFOR_ORSTUDIO == 1) ? 0 : p[t][iTEXTURE];
	} 
	--> PLANT_TREE(x,y,z,n,t,txt)P(n)
P(n) : (n == 0) {	/* planting done. trigger to start growth */
	  curr_y = pMAX_YEARS;
	}
	--> *

B : (pFOR_ORSTUDIO == 0) --> BACKGROUND(hGROUND_W,hGROUND_D,hBGROUND_H)

/* A(n,t,s,w,e) is an apex.
 *	n: which tree to grow
 * 	s: the year that it became the leader. curr_y-s is the age of the apex.
 *	w: width of the internode that the apex is to manifest.
 *	e: estimated life time of the branch. It is set at creation and carried by top apex.
 *
 * When growing, an apex is replaced by a new internode and new apexes.
 * We carry the width info of new branches in the new apexes
 * so that the apexes do not have to ask mother branch later.
 * Apexes stop growing when the width is too thin or likely dead.
 */

/* kill apexes if too thin, or set to die as 0 width */
V(r,a)?H(x,y,z)A(n,s,w,e) : (w < p[trees[n][2]][iWID_MIN]) --> *

/* clean-up unused productions */
[SE] --> *

/* otherwise, grow the apex to an internode with new apexes.
 *
 * HACK: we need to generate multiple apexes depending on calculation.
 * However, CPFG doesn't seem to allow multiple productions based on 
 * condition without extra iteration. I can't use an iteration because
 * the iteration is already used as a year for me.
 * Instead, I'm hard-coding with max productions and some of which will
 * have 0 width, which will be harmlessly killed in the next iteration.
 */
?H(x,y,z)A(n,s,w,e) : (curr_y > 0 && n == curr_n) 
	{ 
	  age = curr_y - s;	/* the current age of the branch */
	  fy = fabs(y);		/* vertical intensity */
	  t = trees[n][2];	/* tree type */

	  /* length of the current internode */
	  if (curr_y == 1 && p[t][iSTART_DEPTH] < 0) { /* force branching undergound */
	    len_0 = 0.01;
	  } else {
	    len_0 = LEN(t, w);
	    len_0 = NRAN(len_0);
	  }

	  /* calculate the vector of the next top apexes. */
	  span = (0.2 + 0.8 * fy) * 180;
	  top_r = 90 + ran(span) - span / 2; /* horizonals tend to stay horizontal */
	  top_r = (ran(1) < 0.5) ? top_r : top_r + 180; /* alternate randomly */
	  top_a = NRAN(p[t][iT_ANG]);

	  /* calculate # of next lateral branches to live */
	  live_l = 0;
	  if (curr_y == 1 && p[t][iSTART_DEPTH] < 0) { /* force branching undergound */
	    live_l = ceil(ran(p[t][iL_MAX]));
	    i = 0;
	    while (i < hL_PROD_ARRAY_SIZE) {
	      l_w[i] = (i < live_l) ? 1 : 0;	/* mark it alive or dead */
	      i = i + 1;
	    }
	  } else {
	    i = 0;
	    while (i < hL_PROD_ARRAY_SIZE) {
	      if (i < p[t][iL_MAX] && IS_L_ALIVE(t, e, age)) {
	        l_w[i] = 1;	/* mark it alive */
	        live_l = live_l + 1; 
	      } else {
	        l_w[i] = 0;	/* mark it dead */
	      }
	      i = i + 1;
	    }
	  }

	  /* calculate width of next lateral branches */
	  if (live_l > 0) { 
	    top_w = T_WID(t, w);
	    lat_w = L_WID(t, w, live_l);
	  } else {
	    top_w = w * hT_WID_R_MAX; 
	    lat_w = 0;
	    e = age + LIFE(t, top_w);	/* no branching: adjust estimate life */
	    if (e > pMAX_YEARS) { e = pMAX_YEARS; }
	  }

	  /* populate branch info for the next lateral apexes.
	   * start the first lateral at the opposite side of top apex.
	   * then, distribute with equi-angle. this can produce
	   * alternate (L_MAX=1), opposite (L_MAX=2), flush (L_MAX>2)
	   * branching with one logic.
	   */
	  i = 0; 
	  lr = top_r + 180; lr_inc = 360 / p[t][iL_MAX];
	  while (i < p[t][iL_MAX]) {
	    if (l_w[i] > 0) { /* live branch */
	      l_r[i] = lr + i * lr_inc + nran(0,10);
	      l_a[i] = NRAN(p[t][iL_ANG]);
	      l_w[i] = NRAN(lat_w);
	      l_e[i] = LIFE(t, l_w[i]);
	      if (l_e[i] < 1) { l_e[i] = 1; }
	      if (l_e[i] > pMAX_YEARS) { l_e[i] = pMAX_YEARS; }
	    }
	    i = i + 1;
	  }

	  /* get the tropism for gravity */
	  if (age < e / 2) {	/* use the first half line: [start,middle] */
	    cut = age;
	    gi_0 = p[t][iGRAV_SI];
	    gi_1 = p[t][iGRAV_MI];
	  }
	  else { /* use the second half line: [middle, end] */
	    cut = age - e / 2;
	    gi_0 = p[t][iGRAV_MI];
	    gi_1 = p[t][iGRAV_EI];
	  }
	  tp = 2 * (gi_1 - gi_0) / e * cut + gi_0;
	  if (tp == 0) { tp = 0.00001; }  /* HACK to avoid weird behavior of CFP at zero tropism */
	}
	--> @Ts(1,tp)!(w)N(len_0)				/* draw the internode */
	[SV(l_r[0],l_a[0])?H(0,0,0)A(n,curr_y,l_w[0],l_e[0])E]	
	[SV(l_r[1],l_a[1])?H(0,0,0)A(n,curr_y,l_w[1],l_e[1])E]	
	[SV(l_r[2],l_a[2])?H(0,0,0)A(n,curr_y,l_w[2],l_e[2])E]	
	[SV(l_r[3],l_a[3])?H(0,0,0)A(n,curr_y,l_w[3],l_e[3])E]	
	[SV(l_r[4],l_a[4])?H(0,0,0)A(n,curr_y,l_w[4],l_e[4])E]	
	[SV(l_r[5],l_a[5])?H(0,0,0)A(n,curr_y,l_w[5],l_e[5])E]	
	[SV(l_r[6],l_a[6])?H(0,0,0)A(n,curr_y,l_w[6],l_e[6])E]	
	[SV(l_r[7],l_a[7])?H(0,0,0)A(n,curr_y,l_w[7],l_e[7])E]	
	[SV(l_r[8],l_a[8])?H(0,0,0)A(n,curr_y,l_w[8],l_e[8])E]	
	[SV(l_r[9],l_a[9])?H(0,0,0)A(n,curr_y,l_w[9],l_e[9])E]	
	V(top_r,top_a)?H(0,0,0)A(n,s,top_w,e)	/* top apex */

/* The stems are drawn in homomorphism in order not to interfere
 * the growth productions. 
*/

homomorphism: warnings

/* Start/end a generalized cylinder for a new branch */
S --> {(1)f(0)
E --> }(1)

/* Set the direction vector:
 * rotate and pitch down, but always recover the rotation angle to the ground 
 */
V(r,a) --> /(r)&(a)@v

/* Draw the internode. Note that homomorphism is re-evaluated even at every 
 * mouse operation. This could slow down interactive viewing substantially.
 * Use either of the following depending on the speed.
*/
/* simple straightforward line */
N(l) --> f(1)
/* with some jittering.
N(l) --> f(l/4)+(4)f(l/4)-(6)f(l/2)+(2)
*/

endlsystem
