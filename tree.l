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
 * See LEN() for the formula.
 * TODO: we probably do not need this tweak if pruning does a good job.
 *
 * 3. Pruning apexes
 * I apply pruning only for lateral branches.
 * Lateral branches die as they get old due to lack of light or space. 
 * Heavier pruning rate is applied for the lateral braches coming out of
 * old mother branch using a power function.
 * See IS_L_ALIVE() for the formula.
 *
 * 4. Applying tropism for gravity
 * Branch direction is also heavily affected by gravity. I apply gravity
 * factor as tropism parameter. Gravity factors for a branch are specified
 * at three points: start, mid, end of the branch. Gravity factor for a certain
 * stem section of a branch is chosen based on the age of the stem relative
 * to the estimated life time of the branch. The estimate life time of a branch
 * is calcuated based on the fact that the width at n-th year will be
 * w*r^n, where n needs to be adjusted for the year when no branching occurs.
 * See LIFE() for the formula.
 *
 * 5. Other notes
 * - All measurements are in centimeter in length, degree in angle.
 * - Each iteration of my L-system represents a year. The iteration stops
 *   when it reaches pMAX_YEARS or no new lateral branch is created.
 * - The coordinate of the planting space: <x, y, z> where
 *   x indicates horizonal axis and 0 is at the center;
 *   y indicates vertical axis and 0 is at the bottom;
 *   z indicates depth axis and 0 is the front of the ground plane,
 *   and positive toward background wall. So, the center of planting ground
 *   would be <0, 0, d/2>, where d is the max depth of the ground. 
 * - Deterministic productions (rather than stochastic) are used; 
 *   Hence, the order of the productions in the program are important.
 *
 * by Pyungchul Kim, 2024
 * https://orderedrandom.com
 */

/* Program-wide parameters - hard-coded.
 * Prefixed by 'h' for program readability.
 */
#define	hL_PROD_ARRAY_SIZE	10	/* max # of lateral productions */
#define hT_WID_R_MAX		0.98	/* width reduction rate when no branching */
#define hSTD_R			0.2	/* ratio of std to mean for nran() */
#define hMAX_TREES		1000	/* max # of trees to plant */
#define hBACK_TEXTURE 		1    	/* background texture: 0 for none */
#define hGROUND_TEXTURE 	2    	/* ground texture: 0 for none */
#define hBGROUND_H		3000	/* background height */
#define hMAX_RELOC		100	/* max # of relocating trees to keep distance */

/* Frequently-used nran in the program: 20% as std, always positive */
#define NRAN(m)			fabs(nran(m, (m) * hSTD_R))

/* Program-wide parameters - can be set by 'param' panel.
 * Prefixed by 'p' for program readability.
 */
#define pSEED 0	/* 0 for no seed setting */
#define pMAX_YEARS 54	/* # of iteration - each step for a year */
#define pFOR_ORSTUDIO 1		/* for ORStudio input: no BG, no texture */
#define pGROUND_D 2925	/* ground depth */
#define pGROUND_W 3985	/* ground width */

/* Number of trees to plant for each type - can be set by 'planting' panel */
#define pNUM_TREE_0 10
#define pNUM_TREE_1 0
#define pNUM_TREE_2 0
#define pNUM_TREE_3 0
#define pNUM_TREE_4 0
#define pNUM_TREE_5 0
#define pNUM_TREE_6 0
#define pNUM_TREE_7 0
#define pNUM_TREE_8 0
#define pNUM_TREE_9 0
#define pNUM_TREE_10 0
#define pNUM_TREE_11 0
#define hMAX_TREE_TYPES		12	/* max # of pre-packaged tree types */

/* Parameters for each tree species.
 * Prefixed by 't' for program readability.
 * - use 'param' panel to customize these parameters.
 * - later, a defined set of parameters can be packaged into predefined tree types
 */
#define tWID_MIN 4		/* min width to grow down to */
#define tWID_MAX 40	/* lowest trunk width */
#define tPRUN_R 0.670000	/* pruning rate */
#define tLEN_MIN 23	/* min internode length */
#define tLEN_MAX 55	/* max internode length */
#define tL_MAX 3	/* max # of lateral branch. max=L_PROD_ARRAY_SIZE */
#define tT_WID_R 0.830000	/* top width to mother when branching. 1 for all top */ 
#define tT_ANG 9	/* mean for top apex angle. degree of alternation */
#define tL_ANG 94	/* mean for lateral apex angle */
#define tGRAV_SI -0.190000		/* gravity intensity of branch start */
#define tGRAV_MI -0.080000		/* gravity intensity of branch middle */
#define tGRAV_EI -0.030000		/* gravity intensity of branch end */
#define tSTART_DEPTH -0.333333			/* depth of the first branching - no pruning */
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
	  1.0, 90.0, 0.5, 15.0, 66.0, 2, 0.85, 5, 40, -0.05, 0.04, 0.02, 0, 3,

	  /* type-2: birch */
	  1.0, 45.0, 0.48, 15.0, 60.0, 2, 0.90, 10, 60, -0.03, 0.03, 0.17, 0, 3,

	  /* type-3: cedar */
	  1.0, 90.0, 0.7, 10.0, 66.0, 6, 0.95, 0, 100, 0.05, -0.06, -0.02, 0, 3,

	  /* type-4: cherry */
	  1.0, 45.0, 0.5, 15.0, 66.0, 4, 0.77, 10, 50, 0.03, 0.02, -0.08, 0, 3,

	  /* type-5: cottonwood */
	  1.0, 60.0, 0.27, 10.0, 90.0, 2, 0.85, 5, 80, -0.1, 0.05, 0.12, 0, 3,

	  /* type-6: oak */
	  1.0, 45.0, 0.04, 10.0, 72.0, 1, 0.8, 25, 70, 0.04, -0.06, 0.08, 0, 3,

	  /* type-7: pine */
	  1.0, 60.0, 0.2, 15.0, 72.0, 6, 0.9, 10, 100, -0.07, 0.03, -0.03, 0, 3,

	  /* type-8: weeping willow */
	  1.0, 45.0, 0.04, 30.0, 50.0, 1, 0.8, 10, 40, -0.09, 0.08, 0.2, 0, 3,

	  /* type-9: rhody */
	  1.0, 30.0, 0.9, 7.5, 45.0, 4, 0.70, 20, 50, 0.13, -0.11, -0.04, -5.0, 3,

	  /* type-10: vine maple */
	  0.5, 15.0, 0.6, 7.5, 75.0, 2, 0.6, 15, 45, -0.15, 0, 0.08, -30.0, 3,

	  /* type-11: fir */
	  1.0, 90.0, 0.62, 10.0, 60.0, 6, 0.92, 1, 65, 0.05, -0.01, 0.04, 0, 3
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

/* NOTE: I use curr_y to control the iterations between planting and growing.
 * A negative number (-1) of curr_y indicates planting iterations. 0 indicates
 * the start of planting, any positive integer indicates i-th year of growth.
 * The growing ends when curr_y has reached pMAX_YEARS.
 */	

start: {
	curr_y = -1; 	/* flag that growth has not started */
	if (pSEED != 0) { srand(pSEED); }	/* set random seed */

	/* Calculate where to plant the trees and put them into the placeholder. */
	t = 0;
	n = 0;
	while (t < hMAX_TREE_TYPES) {
	  i = 0;
	  while (i < n_t[t]) {

	    /* loop hMAX_RELOC to find the farthest location from other trees */
	    md = 0; k = 0;
	    while (k < hMAX_RELOC) {
	      wk = ran(pGROUND_W) - pGROUND_W / 2;
	      dk = ran(pGROUND_D);

	      mdk = 1000000; j = 0;
	      while (j < n) {
		dj = sqrt((trees[j][0] - wk)^2 + (trees[j][1] - dk)^2);
		if (dj < mdk) {
		  mdk = dj;
	      	}
		j = j + 1;
	      }
	      if (mdk > md) {	/* a farther one is found */
		w = wk;
		d = dk;
		md = mdk;
	      }
	      k = k + 1;
	    }
	    
	    /* save the tree info at the placeholder */
	    if (n < hMAX_TREES) {
	      trees[n][0] = w;
	      trees[n][1] = d;
	      trees[n][2] = t;
	      n = n + 1;
	    }
	    i = i + 1;
	  }
	  t = t + 1;
	}
	if (n == 1) {	/* special case: plant at the vintage point for debugging */
	  trees[0][0] = 0;
	  trees[0][1] = pGROUND_D / 4;
	}

	total_trees = n;
	printf("Number of trees to plant: %0.f\n", n);
	apexes = 0;	/* keep track of # of apexes processed at each iteration */
}

starteach: {
	if (curr_y >=0) {
	  printf("Year: %0.f\n", curr_y); 
	}
}

endeach: {
	/* Use stop(1) to display the trees as they grow.
	 * Without this, it won't display at all until all iterations are done.
	 */
	if (curr_y == 0) {  /* all trees are ready to grow */
	  stop(1);
	}
	if (curr_y == pMAX_YEARS || (curr_y > (pMAX_YEARS / 2) && apexes < 2)) {
	  /* either years have exhausted or no new lateral branch grows */
	  printf("\nAll done!\n");
	  stop(0);	/* stop the simulation */
	}
	if (curr_y >=0) {	/* growing: advance to next year */
	  apexes = 0;
	  curr_y = curr_y + 1;
	}
}

/* Background and ground plain */
#define BACKGROUND(txtg,txtbg,w,d,h) 	\
	[@Tx(txtbg);(0)!(0.3)@M(-w/2,0,d){f(h)-(90)f(w)-(90)f(h)-(90)f(w)}] \
	[@Tx(txtg);(0)!(0.3)@M(-w/2,0,0){^(90)f(d)-(90)f(w)-(90)f(d)-(90)f(w)}]

/* Planting a new tree (type=t) at location (x,y,z) */
#define PLANT_TREE(x,y,z,n,t,txt,c)	@M(x,y,z)@Tx(txt);(c)!(p[t][iWID_MAX])[SV(0,0)A(n,0,p[t][iWID_MAX],pMAX_YEARS)E]

derivation length: 1000000

axiom: 	P(total_trees)B

/* Plant all trees first, then grow them altogether a year per iteration.
 * The approach to grow one tree after another takes too long 
 * due to useless scans of productions.
 */
P(n) : (n > 0) 
	{
	  n = n - 1; 
	  x = trees[n][0];
	  z = trees[n][1];
	  t = trees[n][2];
	  y = p[t][iSTART_DEPTH];
	  txt = p[t][iTEXTURE];
	  c = 15; /* default color */
	  /* set texture and color differently for ORStudio input */
	  if (pFOR_ORSTUDIO == 1) {
	    txt = 0;
	    c = (n * 13) % 240 + 16;	/* jump prime number skipping the first 16 grays */
	  }
	} 
	--> PLANT_TREE(x,y,z,n,t,txt,c)P(n)
P(n) : (n == 0) 
	{	/* planting done. trigger to start growth */
	  curr_y = 0;
	}
	--> *

B : * 
	{
	  if (pFOR_ORSTUDIO == 1) {
	    txtg = 0;
	    txtbg = 0;
	  }
	  else {
	    txtg = hGROUND_TEXTURE;
	    txtbg = hBACK_TEXTURE;
	  }
	} --> BACKGROUND(txtg, txtbg, pGROUND_W,pGROUND_D,hBGROUND_H)

/* A(n,t,s,w,e) is an apex.
 *	n: which tree to grow
 * 	s: the year that it became the leader (i.e., birth year).
 *	w: width of the internode that the apex is to manifest.
 *	e: estimated life time of the branch. It is set at creation and carried by top apex.
 *
 * When growing, an apex is replaced by a new internode and new apexes.
 * We carry the width info of new branches in the new apexes
 * so that the apexes do not have to ask mother branch later.
 * Apexes stop growing when the width is too thin or likely dead.
 */

/* kill apexes if too thin, or set to die as 0 width */
V(r,a)A(n,s,w,e) : (w < p[trees[n][2]][iWID_MIN]) --> *

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
A(n,s,w,e) : (curr_y > 0) 
	{ 
	  apexes = apexes + 1;
	  age = curr_y - s;	/* the current age of the branch */
	  t = trees[n][2];	/* tree type */

	  /* length of the current internode */
	  if (curr_y == 1 && p[t][iSTART_DEPTH] < 0) { /* force branching undergound */
	    len_0 = 0.3;
	  } else {
	    len_0 = LEN(t, w);
	    len_0 = NRAN(len_0);
	  }

	  /* calculate the vector of the next top apexes. */
	  top_r = ran(360);
	  top_a = NRAN(p[t][iT_ANG]);

	  /* calculate # of next lateral branches to live */
	  live_l = 0;
	  if (curr_y == 1 && p[t][iSTART_DEPTH] < 0) { 
	    /* force branching undergound without pruning */
	    live_l = ceil(ran(p[t][iL_MAX]));
	    i = 0;
	    while (i < hL_PROD_ARRAY_SIZE) {
	      l_w[i] = (i < live_l) ? 1 : 0;
	      i = i + 1;
	    }
	  } else {
	    /* fork lateral branches with pruning applied */
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

	  /* calculate width of next top/lateral branches */
	  if (live_l > 0) { /* branching occurs: use Da Vinci formula */
	    top_w = T_WID(t, w);
	    lat_w = L_WID(t, w, live_l);
	  } else {
	    /* no branching occurs: reduce next top branch width by 
	     * hard-coded rate, and adjust estimate life based upon new width.
	     */
	    top_w = w * hT_WID_R_MAX; 
	    lat_w = 0;
	    e = age + LIFE(t, top_w);
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
	--> @Ts(1,tp)!(w)N(len_0) 	/* draw the internode */
	[SV(l_r[0],l_a[0])A(n,curr_y,l_w[0],l_e[0])E]	
	[SV(l_r[1],l_a[1])A(n,curr_y,l_w[1],l_e[1])E]	
	[SV(l_r[2],l_a[2])A(n,curr_y,l_w[2],l_e[2])E]	
	[SV(l_r[3],l_a[3])A(n,curr_y,l_w[3],l_e[3])E]	
	[SV(l_r[4],l_a[4])A(n,curr_y,l_w[4],l_e[4])E]	
	[SV(l_r[5],l_a[5])A(n,curr_y,l_w[5],l_e[5])E]	
	[SV(l_r[6],l_a[6])A(n,curr_y,l_w[6],l_e[6])E]	
	[SV(l_r[7],l_a[7])A(n,curr_y,l_w[7],l_e[7])E]	
	[SV(l_r[8],l_a[8])A(n,curr_y,l_w[8],l_e[8])E]	
	[SV(l_r[9],l_a[9])A(n,curr_y,l_w[9],l_e[9])E]	
	V(top_r,top_a)A(n,s,top_w,e)	/* top apex */

/* The stems are drawn in homomorphism in order not to interfere
 * the growth productions. For some reason, it also gives better performance.
*/

homomorphism: warnings

/* Vector (direction) of an apex: rotate and pitch down */
V(r,a) --> /(r)&(a)

/* Start/end a generalized cylinder for a new branch */
S --> {(1)f(0)
E --> }(1)

/* Draw the internode. Note that homomorphism is re-evaluated even at every 
 * mouse operation. This could slow down interactive viewing substantially.
 * Use either of the following depending on the speed.
*/
/* simple straightforward line */
N(l) --> f(l)
/* with some jittering.
N(l) --> f(l/4)+(4)f(l/4)-(6)f(l/2)+(2)
*/

endlsystem
