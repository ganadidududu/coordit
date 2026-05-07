// Coordit Fit Lab — Three.js 3D mannequin component
// Matte atelier torso, drag-to-rotate, with fit-state measurement rings + HTML overlay labels.

const Body3DComponent = (() => {
  function Body3D({ width = 500, height = 720 }) {
    const mountRef = React.useRef(null);
    const rafRef = React.useRef(null);
    const stateRef = React.useRef({ rotY: 0.35, targetY: 0.35, dragging: false, lastX: 0 });
    const [labels, setLabels] = React.useState({});

    React.useEffect(() => {
      const mount = mountRef.current;
      if (!mount || !window.THREE) return;

      const THREE = window.THREE;
      const scene = new THREE.Scene();
      scene.background = null;

      // Wider FOV + framed to see head to toe
      const camera = new THREE.PerspectiveCamera(30, width / height, 0.1, 100);
      camera.position.set(0, 0, 9);
      camera.lookAt(0, 0, 0);

      const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
      renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
      renderer.setSize(width, height);
      renderer.outputColorSpace = THREE.SRGBColorSpace || THREE.sRGBEncoding;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.1;
      mount.appendChild(renderer.domElement);

      // ── LIGHTS ── editorial studio lighting
      const key = new THREE.DirectionalLight(0xf5e9cf, 1.5);
      key.position.set(-3, 4, 4);
      scene.add(key);

      const rim = new THREE.DirectionalLight(0xb08a5b, 1.0);
      rim.position.set(4, 2, -3);
      scene.add(rim);

      const fill = new THREE.DirectionalLight(0x8a7a6a, 0.4);
      fill.position.set(0, -2, 4);
      scene.add(fill);

      const ambient = new THREE.AmbientLight(0x2a2420, 0.4);
      scene.add(ambient);

      // ── MANNEQUIN MATERIAL ── matte porcelain/plaster
      const skinMat = new THREE.MeshStandardMaterial({
        color: 0xd4b896,
        roughness: 0.85,
        metalness: 0.05,
      });

      // ── MANNEQUIN ── group holding all body parts
      const figure = new THREE.Group();

      // Head (oval)
      const head = new THREE.Mesh(
        new THREE.SphereGeometry(0.22, 32, 24),
        skinMat
      );
      head.scale.set(0.85, 1.05, 0.9);
      head.position.y = 3.05;
      figure.add(head);

      // Neck
      const neck = new THREE.Mesh(
        new THREE.CylinderGeometry(0.09, 0.11, 0.22, 24),
        skinMat
      );
      neck.position.y = 2.75;
      figure.add(neck);

      // Torso — more human proportions via curved LatheGeometry
      const torsoProfile = [
        new THREE.Vector2(0.32, 0.0),
        new THREE.Vector2(0.30, 0.15),
        new THREE.Vector2(0.27, 0.35),
        new THREE.Vector2(0.28, 0.55),
        new THREE.Vector2(0.34, 0.85),
        new THREE.Vector2(0.36, 1.00),
        new THREE.Vector2(0.40, 1.15),
        new THREE.Vector2(0.38, 1.25),
        new THREE.Vector2(0.22, 1.35),
        new THREE.Vector2(0.14, 1.40),
      ];
      const torsoGeom = new THREE.LatheGeometry(torsoProfile, 48);
      torsoGeom.scale(1.08, 1.0, 0.72);
      const torso = new THREE.Mesh(torsoGeom, skinMat);
      torso.position.y = 1.25;
      figure.add(torso);

      // Hips
      const hipProfile = [
        new THREE.Vector2(0.32, 0.0),
        new THREE.Vector2(0.36, 0.10),
        new THREE.Vector2(0.38, 0.22),
        new THREE.Vector2(0.36, 0.35),
        new THREE.Vector2(0.30, 0.45),
      ];
      const hipGeom = new THREE.LatheGeometry(hipProfile, 48);
      hipGeom.scale(1.1, 1.0, 0.78);
      const hips = new THREE.Mesh(hipGeom, skinMat);
      hips.position.y = 0.85;
      figure.add(hips);

      // Arms
      function makeArm(sideX) {
        const arm = new THREE.Group();
        const upper = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.075, 0.72, 20), skinMat);
        upper.position.set(0, -0.36, 0);
        arm.add(upper);
        const fore = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.06, 0.6, 20), skinMat);
        fore.position.set(0, -1.02, 0);
        arm.add(fore);
        const elbow = new THREE.Mesh(new THREE.SphereGeometry(0.08, 20, 16), skinMat);
        elbow.position.set(0, -0.72, 0);
        arm.add(elbow);
        const shoulder = new THREE.Mesh(new THREE.SphereGeometry(0.12, 20, 16), skinMat);
        arm.add(shoulder);
        const hand = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.22, 0.08), skinMat);
        hand.position.set(0, -1.42, 0);
        arm.add(hand);
        arm.position.set(sideX * 0.44, 2.5, 0);
        arm.rotation.z = sideX * 0.08;
        return arm;
      }
      figure.add(makeArm(-1), makeArm(1));

      // Legs
      function makeLeg(sideX) {
        const leg = new THREE.Group();
        const thigh = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.11, 0.88, 20), skinMat);
        thigh.position.set(0, -0.44, 0);
        leg.add(thigh);
        const knee = new THREE.Mesh(new THREE.SphereGeometry(0.12, 20, 16), skinMat);
        knee.position.set(0, -0.88, 0);
        leg.add(knee);
        const calf = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.08, 0.82, 20), skinMat);
        calf.position.set(0, -1.32, 0);
        leg.add(calf);
        const foot = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.1, 0.32), skinMat);
        foot.position.set(0, -1.78, 0.06);
        leg.add(foot);
        leg.position.set(sideX * 0.16, 0.85, 0);
        return leg;
      }
      figure.add(makeLeg(-1), makeLeg(1));

      figure.position.y = -1.4;
      figure.scale.setScalar(0.72);
      scene.add(figure);

      // ── FIT-STATE MEASUREMENT RINGS ── each ring has color + glow + "anchor" for HTML label
      // Fit states: tight (red), perfect (green), loose (purple)
      const FIT_COLORS = {
        tight:   { ring: 0xc85a4e, glow: 0xff7a68, css: '#D66A5D' },
        perfect: { ring: 0x6b8a60, glow: 0x9acc80, css: '#7FA870' },
        loose:   { ring: 0x8d7fb5, glow: 0xb5a8e0, css: '#9D90C7' },
      };

      // Glowing ring: thick tube + subtle outer sprite-less halo (double torus trick)
      function makeFitRing(fitKey, radius, yOffset, squeezeZ = 0.72) {
        const col = FIT_COLORS[fitKey];
        const group = new THREE.Group();

        // Inner bright ring
        const innerGeom = new THREE.TorusGeometry(radius, 0.028, 14, 120);
        const inner = new THREE.Mesh(innerGeom, new THREE.MeshBasicMaterial({
          color: col.ring, transparent: true, opacity: 1.0, side: THREE.DoubleSide,
        }));
        inner.rotation.x = Math.PI / 2;
        group.add(inner);

        // Outer glow ring (larger torus, lower opacity)
        const outerGeom = new THREE.TorusGeometry(radius, 0.055, 14, 120);
        const outer = new THREE.Mesh(outerGeom, new THREE.MeshBasicMaterial({
          color: col.glow, transparent: true, opacity: 0.28, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false,
        }));
        outer.rotation.x = Math.PI / 2;
        group.add(outer);

        // Thin precision marker (darker, absolutely crisp)
        const markerGeom = new THREE.TorusGeometry(radius, 0.006, 8, 120);
        const marker = new THREE.Mesh(markerGeom, new THREE.MeshBasicMaterial({
          color: 0x1a1612, transparent: true, opacity: 0.6,
        }));
        marker.rotation.x = Math.PI / 2;
        group.add(marker);

        group.scale.set(1.08, squeezeZ, 1.0);
        group.position.y = yOffset;
        group.userData.radius = radius;
        return group;
      }

      // Shoulder: Tight — ring at shoulder line (figure y=2.40 == highest torso)
      const shoulderRing = makeFitRing('tight', 0.44, 2.40);
      figure.add(shoulderRing);

      // Chest: Perfect (widest point)
      const chestRing = makeFitRing('perfect', 0.38, 2.10);
      figure.add(chestRing);

      // Waist: Loose
      const waistRing = makeFitRing('loose', 0.31, 1.60);
      figure.add(waistRing);

      // Hip: Perfect (subtle)
      const hipRing = makeFitRing('perfect', 0.38, 0.95);
      // lower hip opacity
      hipRing.children[0].material.opacity = 0.55;
      hipRing.children[1].material.opacity = 0.14;
      figure.add(hipRing);

      // ── CALIPER BRACKETS ── white/camel L-brackets on each side of fit rings (cheat: small arcs outside figure)
      function makeCaliper(fitKey, radius, yOffset, squeezeZ = 0.72) {
        const col = FIT_COLORS[fitKey];
        const group = new THREE.Group();
        const calR = radius * 1.15; // slightly larger than ring
        // Short arcs on left and right side (±20 degrees around ±X axis)
        for (const sign of [-1, 1]) {
          const arcGeom = new THREE.TorusGeometry(calR, 0.008, 8, 32, Math.PI / 7);
          const arc = new THREE.Mesh(arcGeom, new THREE.MeshBasicMaterial({
            color: 0xf5e9cf, transparent: true, opacity: 0.85,
          }));
          arc.rotation.x = Math.PI / 2;
          arc.rotation.y = sign > 0 ? -Math.PI / 14 : Math.PI - Math.PI / 14;
          group.add(arc);
        }
        group.scale.set(1.08, squeezeZ, 1.0);
        group.position.y = yOffset;
        return group;
      }
      figure.add(makeCaliper('tight', 0.44, 2.40));
      figure.add(makeCaliper('perfect', 0.38, 2.10));
      figure.add(makeCaliper('loose', 0.31, 1.60));
      figure.add(makeCaliper('perfect', 0.38, 0.95));

      // ── FLOOR — circular platform ──
      const platform = new THREE.Mesh(
        new THREE.CircleGeometry(1.6, 64),
        new THREE.MeshStandardMaterial({ color: 0x1a1612, roughness: 0.95, metalness: 0 })
      );
      platform.rotation.x = -Math.PI / 2;
      platform.position.y = -1.62;
      scene.add(platform);

      // Platform rim glow
      const rimRing = new THREE.Mesh(
        new THREE.TorusGeometry(1.6, 0.008, 8, 128),
        new THREE.MeshBasicMaterial({ color: 0xd4b896, transparent: true, opacity: 0.4 })
      );
      rimRing.rotation.x = Math.PI / 2;
      rimRing.position.y = -1.615;
      scene.add(rimRing);

      // ── LABEL ANCHORS ── tracked via projection to DOM overlay
      // Anchor points sit on the RIGHT edge of each ring (local x = radius * squeezeX, y=ring y)
      // We project them every frame and update React state via setLabels.
      const anchors = [
        { id: 'shoulder', part: '어깨', en: 'SHOULDER', state: 'TIGHT',   fit: 'tight',   delta: '-1.5cm', y: 2.40, r: 0.44 },
        { id: 'chest',    part: '가슴', en: 'CHEST',    state: 'PERFECT', fit: 'perfect', delta: '+4.0cm', y: 2.10, r: 0.38 },
        { id: 'waist',    part: '허리', en: 'WAIST',    state: 'LOOSE',   fit: 'loose',   delta: '+6.0cm', y: 1.60, r: 0.31 },
        { id: 'hip',      part: '힙',   en: 'HIP',      state: 'PERFECT', fit: 'perfect', delta: '+1.5cm', y: 0.95, r: 0.38 },
      ];
      const anchorVec = new THREE.Vector3();

      function projectAnchors() {
        const next = {};
        for (const a of anchors) {
          // local point at +x edge of the ring in figure coords (ring squeezeX = 1.08)
          anchorVec.set(a.r * 1.08, a.y, 0);
          // apply figure's transform (position + scale + rotation)
          const v = anchorVec.clone();
          figure.localToWorld(v);
          v.project(camera);
          // convert NDC to pixels
          const x = (v.x * 0.5 + 0.5) * width;
          const y = (-v.y * 0.5 + 0.5) * height;
          // if behind camera or off-screen laterally, hide label
          const visible = v.z < 1 && x > 0 && x < width;
          next[a.id] = { ...a, x, y, visible, css: FIT_COLORS[a.fit].css };
        }
        setLabels(next);
      }

      // ── DRAG ROTATION ──
      const canvas = renderer.domElement;
      canvas.style.cursor = 'grab';
      canvas.style.display = 'block';
      canvas.style.width = width + 'px';
      canvas.style.height = height + 'px';

      const onDown = (e) => {
        stateRef.current.dragging = true;
        stateRef.current.lastX = e.clientX ?? (e.touches && e.touches[0].clientX);
        canvas.style.cursor = 'grabbing';
      };
      const onUp = () => {
        stateRef.current.dragging = false;
        canvas.style.cursor = 'grab';
      };
      const onMove = (e) => {
        if (!stateRef.current.dragging) return;
        const x = e.clientX ?? (e.touches && e.touches[0].clientX);
        const dx = x - stateRef.current.lastX;
        stateRef.current.lastX = x;
        stateRef.current.targetY += dx * 0.008;
      };

      canvas.addEventListener('mousedown', onDown);
      window.addEventListener('mouseup', onUp);
      window.addEventListener('mousemove', onMove);
      canvas.addEventListener('touchstart', onDown, { passive: true });
      window.addEventListener('touchend', onUp);
      window.addEventListener('touchmove', onMove, { passive: true });

      // ── ANIMATION LOOP ──
      let frameCount = 0;
      const tick = () => {
        stateRef.current.rotY += (stateRef.current.targetY - stateRef.current.rotY) * 0.08;
        if (!stateRef.current.dragging) {
          stateRef.current.targetY += 0.0015;
        }
        figure.rotation.y = stateRef.current.rotY;
        renderer.render(scene, camera);
        // Project labels every 2 frames (~30Hz enough)
        if (frameCount++ % 2 === 0) projectAnchors();
        rafRef.current = requestAnimationFrame(tick);
      };
      tick();

      return () => {
        cancelAnimationFrame(rafRef.current);
        canvas.removeEventListener('mousedown', onDown);
        window.removeEventListener('mouseup', onUp);
        window.removeEventListener('mousemove', onMove);
        canvas.removeEventListener('touchstart', onDown);
        window.removeEventListener('touchend', onUp);
        window.removeEventListener('touchmove', onMove);
        renderer.dispose();
        if (mount.contains(renderer.domElement)) {
          mount.removeChild(renderer.domElement);
        }
      };
    }, [width, height]);

    // HTML overlay labels positioned via projected anchor coords
    return (
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        pointerEvents: 'none',
      }}>
        <div ref={mountRef} style={{
          position: 'relative', width, height,
          pointerEvents: 'auto',
        }}>
          {/* HTML overlay labels */}
          <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
            {Object.values(labels).map((L) => (
              <div key={L.id} style={{
                position: 'absolute',
                left: L.x, top: L.y,
                transform: 'translate(8px, -50%)',
                opacity: L.visible ? 1 : 0.2,
                transition: 'opacity 0.3s',
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 10,
                letterSpacing: '0.08em',
                color: '#F5F0E6',
                whiteSpace: 'nowrap',
              }}>
                {/* Leader dot + line */}
                <div style={{
                  display: 'inline-flex', alignItems: 'center', gap: 6,
                  background: 'rgba(10, 9, 8, 0.88)',
                  border: `1px solid ${L.css}`,
                  borderLeft: `3px solid ${L.css}`,
                  padding: '6px 10px',
                  backdropFilter: 'blur(6px)',
                }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                      <span style={{ color: '#F5F0E6', fontWeight: 500 }}>{L.en}</span>
                      <span style={{ color: 'rgba(245,240,230,0.5)', fontSize: 9 }}>{L.part}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 3 }}>
                      <span style={{ color: L.css, fontWeight: 600, fontSize: 11 }}>{L.state}</span>
                      <span style={{ color: 'rgba(245,240,230,0.7)', fontFamily: "'Cormorant Garamond', serif", fontSize: 13, fontStyle: 'italic' }}>{L.delta}</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return Body3D;
})();

window.Body3D = Body3DComponent;
