const axios = require('axios');

async function request(query, variables) {
  return axios({
    url: process.env.API_ANIMEAL_GRAPHQLAPIENDPOINTOUTPUT,
    method: 'post',
    headers: {
      'x-api-key': process.env.API_ANIMEAL_GRAPHQLAPIKEYOUTPUT,
    },
    data: {
      query,
      variables,
    },
  });
}

const searchFeedingPoints = async (params) => {
  return request(
    `
    query SearchFeedingPoints(
      $filter: SearchableFeedingPointFilterInput
      $sort: [SearchableFeedingPointSortInput]
      $limit: Int
      $nextToken: String
      $from: Int
      $aggregates: [SearchableFeedingPointAggregationInput]
    ) {
      searchFeedingPoints(
        filter: $filter
        sort: $sort
        limit: $limit
        nextToken: $nextToken
        from: $from
        aggregates: $aggregates
      ) {
        items {
          id
          name
        }
        nextToken
        total
      }
    }
  `,
    params,
  );
};

const updateFeedingPoint = async (params) =>
  request(
    `mutation UpdateFeedingPoint(
      $input: UpdateFeedingPointInput!
      $condition: ModelFeedingPointConditionInput
    ) {
      updateFeedingPoint(input: $input, condition: $condition) {
        id
        name
        description
        city
        street
        address
        images
        point {
          type
          coordinates
        }
        location {
          lat
          lon
        }
        region
        neighborhood
        distance
        status
        i18n {
          locale
          name
          description
          city
          street
          address
          region
          neighborhood
        }
        statusUpdatedAt
        createdAt
        updatedAt
        createdBy
        updatedBy
        owner
        pets {
          items {
            id
            petId
            feedingPointId
            pet {
              id
              name
              images
              breed
              color
              chipNumber
              vaccinatedAt
              yearOfBirth
              createdAt
              updatedAt
              createdBy
              updatedBy
              owner
              cover
              petCategoryId
            }
            feedingPoint {
              id
              name
              description
              city
              street
              address
              images
              region
              neighborhood
              distance
              status
              statusUpdatedAt
              createdAt
              updatedAt
              createdBy
              updatedBy
              owner
              cover
              feedingPointCategoryId
            }
            createdAt
            updatedAt
            owner
          }
          nextToken
        }
        category {
          id
          name
          icon
          tag
          i18n {
            locale
            name
          }
          createdAt
          updatedAt
          createdBy
          updatedBy
          owner
        }
        users {
          items {
            id
            userId
            feedingPointId
            feedingPoint {
              id
              name
              description
              city
              street
              address
              images
              region
              neighborhood
              distance
              status
              statusUpdatedAt
              createdAt
              updatedAt
              createdBy
              updatedBy
              owner
              cover
              feedingPointCategoryId
            }
            createdAt
            updatedAt
            owner
          }
          nextToken
        }
        feedings {
          items {
            id
            userId
            images
            status
            createdAt
            updatedAt
            createdBy
            updatedBy
            owner
            feedingPoint {
              id
              name
              description
              city
              street
              address
              images
              region
              neighborhood
              distance
              status
              statusUpdatedAt
              createdAt
              updatedAt
              createdBy
              updatedBy
              owner
              cover
              feedingPointCategoryId
            }
            expireAt
            feedingPointFeedingsId
          }
          nextToken
        }
        cover
        feedingPointCategoryId
      }
    }
`,
    params,
  );


module.exports = {
  searchFeedingPoints,
  updateFeedingPoint
};
