/* DO NOT MOVE THE LINES OF THE FOLLOWING ITEMS AS THEY ARE REFERENCED
 * BY PANELS WITH LINE NUMBER
 */
view reference point: 0,20,-200.0000
viewpoint: 0,10,-0.0000
viewing angle: 20

/* NOTE: DO NOT ADD COMMENTS AT THE END OF A VALID CONTROL.
 * IT WILL CAUSE A PARSING ERROR.
 */

/* color control - initial color is used for trees */
initial color: 200
color increment: 1

/* line control */
line style: cylinder

/* viewing control */
projection: perspective
front distance: 0.1
back distance: 100000.0

/* rendering control */
render mode: filled
z buffer: on
contour sides: 16

/* light control */
light direction: -1,2,0
diffuse reflection: 7

/* texture for background scene, ground surface followed by tree barks */
texture: F: backdrop1.rgb H: n L: n
texture: F: grass1.rgb H: l L: l
texture: F: bark1.rgb H: l L: n
tropism: T: 0.0 -1.0 0.0
