import type { Category, MeasurementKey } from "../../shared/types/database";

type Impact = { readonly smaller: string; readonly larger: string; readonly same: string };

const impacts: Readonly<Record<Category, Partial<Record<MeasurementKey, Impact>>>> = {
  tshirt: {
    chest_width: { smaller: "몸통이 기준 티셔츠보다 밀착되는 방향이에요.", larger: "몸통이 기준 티셔츠보다 여유롭게 떨어지는 방향이에요.", same: "몸통 실루엣이 기준 티셔츠와 비슷해요." },
    shoulder_width: { smaller: "어깨선이 안쪽으로 이동하는 방향이에요.", larger: "어깨선이 바깥으로 내려오는 방향이에요.", same: "어깨선이 기준 티셔츠와 비슷해요." }
  },
  shirt: {
    chest_width: { smaller: "셔츠 몸통 여유가 줄어 팔을 앞으로 뻗을 때 당김이 생길 수 있어요.", larger: "셔츠 몸통에 여유가 더 생기는 방향이에요.", same: "셔츠 몸통 여유가 기준과 비슷해요." },
    shoulder_width: { smaller: "셔츠 어깨선이 안쪽으로 들어오는 방향이에요.", larger: "셔츠 어깨선이 바깥으로 이동하는 방향이에요.", same: "셔츠 어깨선이 기준과 비슷해요." }
  },
  sweatshirt: {
    chest_width: { smaller: "스웨트셔츠 몸통 볼륨이 줄어드는 방향이에요.", larger: "스웨트셔츠 몸통 볼륨이 늘어나는 방향이에요.", same: "스웨트셔츠 몸통 볼륨이 기준과 비슷해요." }
  },
  hoodie: {
    chest_width: { smaller: "후디 몸통과 이너를 겹쳐 입을 공간이 줄어드는 방향이에요.", larger: "후디 몸통과 레이어링 공간이 늘어나는 방향이에요.", same: "후디의 몸통·레이어링 공간이 기준과 비슷해요." },
    sleeve_length: { smaller: "후디 소매 끝이 기준보다 높게 자리해요.", larger: "후디 소매 끝이 기준보다 낮게 자리해요.", same: "후디 소매 위치가 기준과 비슷해요." }
  },
  knit: {
    chest_width: { smaller: "니트 몸통 실루엣이 기준보다 가까워지는 방향이에요.", larger: "니트 몸통 실루엣이 기준보다 여유로워지는 방향이에요.", same: "니트 몸통 실루엣이 기준과 비슷해요." }
  },
  jacket: {
    chest_width: { smaller: "재킷 여밈과 이너를 겹쳐 입을 공간이 줄어들 수 있어요.", larger: "재킷 여밈과 레이어링 공간이 늘어나는 방향이에요.", same: "재킷 여밈과 레이어링 공간이 기준과 비슷해요." },
    shoulder_width: { smaller: "재킷 어깨 구조가 더 타이트해져 팔 움직임을 확인해야 해요.", larger: "재킷 어깨선이 더 여유로워지는 방향이에요.", same: "재킷 어깨선이 기준과 비슷해요." }
  },
  coat: {
    chest_width: { smaller: "코트 안에 이너를 입을 몸통 공간이 줄어드는 방향이에요.", larger: "코트 안에 이너를 입을 몸통 공간이 늘어나는 방향이에요.", same: "코트의 몸통·레이어링 공간이 기준과 비슷해요." },
    total_length: { smaller: "코트 밑단이 기준보다 높게 끝나요.", larger: "코트 밑단이 기준보다 낮게 끝나요.", same: "코트 밑단 길이가 기준과 비슷해요." }
  },
  pants: {
    waist_width: { smaller: "팬츠 허리 압박이 커질 수 있어 앉았을 때 여유를 확인해야 해요.", larger: "팬츠 허리 고정감이 줄어들 수 있어요.", same: "팬츠 허리 여유가 기준과 비슷해요." },
    hip_width: { smaller: "팬츠 힙 여유가 줄어 앉을 때 당김이 생길 수 있어요.", larger: "팬츠 힙과 앉을 때의 여유가 늘어나는 방향이에요.", same: "팬츠 힙 여유가 기준과 비슷해요." }
  },
  jeans: {
    waist_width: { smaller: "데님 팬츠 허리가 기준보다 좁아 앉았을 때 압박을 확인해야 해요.", larger: "데님 팬츠 허리가 기준보다 여유로워져 고정감을 확인해야 해요.", same: "데님 팬츠 허리 여유가 기준과 비슷해요." },
    rise: { smaller: "데님 팬츠 밑위가 짧아져 앉을 때 허리선 위치가 달라질 수 있어요.", larger: "데님 팬츠 밑위가 길어져 허리선 위치가 달라질 수 있어요.", same: "데님 팬츠 밑위가 기준과 비슷해요." }
  },
  shorts: {
    hip_width: { smaller: "쇼츠 힙 여유가 줄어 앉거나 걸을 때 움직임을 확인해야 해요.", larger: "쇼츠 힙 여유가 늘어나 앉거나 걸을 때 공간이 더 남아요.", same: "쇼츠 힙 여유가 기준과 비슷해요." },
    total_length: { smaller: "쇼츠 밑단이 높아져 다리가 더 드러나는 방향이에요.", larger: "쇼츠 밑단이 낮아져 다리 노출이 줄어드는 방향이에요.", same: "쇼츠 밑단 길이가 기준과 비슷해요." }
  },
  skirt: {
    hip_width: { smaller: "스커트 힙 실루엣이 몸에 더 가까워지는 방향이에요.", larger: "스커트 힙 실루엣에 여유가 더 생기는 방향이에요.", same: "스커트 힙 실루엣이 기준과 비슷해요." },
    total_length: { smaller: "스커트 밑단이 높아지는 방향이에요.", larger: "스커트 밑단이 낮아지는 방향이에요.", same: "스커트 밑단 길이가 기준과 비슷해요." }
  }
};

export const getCategoryMeasurementImpact = (
  category: Category,
  measurement: MeasurementKey,
  diff: number
): string | undefined => {
  const impact = impacts[category][measurement];
  return impact?.[diff < 0 ? "smaller" : diff > 0 ? "larger" : "same"];
};
